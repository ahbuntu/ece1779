require "aws_boilerplate.rb"

class Elb
  include Singleton
  include AwsBoilerplate

  class << self

    def elb
      @elb ||= AWS::ELB.new(:region => default_availability_zone)
    end

    def create_load_balancer(az)
      load_balancer = elb.load_balancers.create('my-load-balancer',
        :availability_zones => [az], # ec2.availability_zones.map(&:name),        
        :listeners => [{
          :port => 80,
          :protocol => :http,
          :instance_port => 80,
          :instance_protocol => :http,
        }, 
        {
          :port => 8080,
          :protocol => :http,
          :instance_port => 80,
          :instance_protocol => :http,
        }])

      # Enable stickiness
      policy = elb.client.create_app_cookie_stickiness_policy({
        :load_balancer_name => load_balancer.name, 
        :policy_name => 'sticky-sessions',
        :cookie_name => 'stickiness', 
        })
      load_balancer.listeners.each do |l|
        l.policy = 'sticky-sessions'
      end

      # Update health check.
      load_balancer.configure_health_check({
        :target=>"HTTP:80/ping",
        :healthy_threshold => 6, 
        :timeout => 10, 
        :unhealthy_threshold => 2,
        :interval => 25
        })

      load_balancer
    end

    def load_balancer
      elb.load_balancers["my-load-balancer"]
    end
  end

  def load_balancer
    Elb.load_balancer
  end

  def reset_alarm_subscriptions!
    # Initialize and point SNS subscriptions to the ELB
    retry_max = 3
    begin
      if load_balancer.instances.health.map(&:state).any?{|s| s == "InService"}
        # point to ELB if any healthy instances
        hostname_or_ip = load_balancer.dns_name
      elsif instance = load_balancer.instances.select{|i| i.status == :running}.first
        hostname_or_ip = instance.public_ip_address
      elsif instance = all_running_instances.first
        # fail-safe: take ANY running instance and try that
        hostname_or_ip = instance.public_ip_address
      else
        raise "Could not find any instance to use as an endpoint for alarm subscriptions!"
      end

      # iterate through Subscriptions and only update those that have an endpoint change
      sns = SNS.instance
      raise "No DNS name for ELB" unless hostname_or_ip.present?
      new_endpoint = SNS.instance.sns_endpoint(hostname_or_ip)

      sns.topics.each do |topic|
        if topic.subscriptions.count == 0
          topic.subscribe(new_endpoint, json: true)
        else
          topic.subscriptions.each do |sub|
            # Hacky: if not subscribed then we can't delete it
            if sub.arn == "PendingConfirmation"
              sub.topic.subscribe(sub.endpoint, json: true)
            elsif new_endpoint != sub.endpoint
              sub.exists? && sub.unsubscribe
              topic.subscribe(new_endpoint, json: true)
            end
          end
        end
      end
    rescue => e
      if retry_max <= 0
        raise e
      else
        retry_max = retry_max - 1
        retry
      end
    end
  end

  def workers
    workers = AWS.memoize do
      load_balancer.instances.map do |i|
        Worker.new(i)
      end
    end rescue []
  end

  def configured?
    Elb.load_balancer.present?
  end

  def register_worker(w)
    load_balancer.instances.register(w.instance.id)
    az = w.instance.availability_zone
    load_balancer.availability_zones.enable(az) unless load_balancer.availability_zones.map(&:name).include?(az)
    w.create_alarms! # paranoia, but that's fine. OR IS IT?!
    reset_alarm_subscriptions!
  end

  def deregister_worker(w)

    # remove the AZ from the ELB if no instances left
    az = w.instance.availability_zone
    other_instance_azs = load_balancer.instances.map do |i|
      i.id == w.instance.id ? nil : i.availability_zone
    end.compact
    load_balancer.availability_zones.disable(az) unless other_instance_azs.include?(az)

    load_balancer.instances.remove(w.instance.id)
    reset_alarm_subscriptions!
  end

  def name
    load_balancer.name
  end

  def url
    "http://#{load_balancer.dns_name}"
  end

  # returns health status in a hash keyed by instance_id
  def health
    health = AWS.memoize do
      load_balancer.instances.health.inject({}) do |h,i|
        instance = i[:instance]
        h[instance.id] = i
        h
      end
    end rescue nil
  end

end
