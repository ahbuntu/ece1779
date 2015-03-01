require "aws_boilerplate.rb"

class Elb
  include Singleton
  include AwsBoilerplate

  class << self

    def elb
      @elb ||= AWS::ELB.new(:region => default_availability_zone)
    end

    def create_load_balancer
      load_balancer = elb.load_balancers.create('my-load-balancer',
        :availability_zones => ["us-east-1a", "us-east-1b", "us-east-1c"],
        :listeners => [{
          :port => 80,
          :protocol => :http,
          :instance_port => 80,
          :instance_protocol => :http,
        }])

      # change health check to HTTP
      load_balancer.configure_health_check({:target=>"HTTP:80/"})

      # enable stickiness
      policy = elb.client.create_lb_cookie_stickiness_policy({
        :load_balancer_name => load_balancer.name, 
        :policy_name => 'sticky-sessions'
        # :cookie_expiration_period # no expiry
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

  def workers
    workers = AWS.memoize do
      load_balancer.instances.map do |i|
        Worker.new(i)
      end
    end rescue []
  end

  def master_instance_id
    # default to the instance with the earliest launch_time
    if @master_instance_id.nil?
      instance = Elb.instance.load_balancer.instances.sort{|a,b| a.launch_time <=> b.launch_time}.first rescue nil
      @master_instance_id = instance.try(:id)
    end
    @master_instance_id
  end

  def master_instance_id=(value)
    return value if @master_instance_id == value

    # Initialize and point SNS subscriptions to the new master
    SNS.instance.unsubscribe_all_topics!

    # HACK!!!
    @master_instance_id = value
    if @master_instance_id.present?
      instance = load_balancer.instances.detect{|i| i.id == @master_instance_id}
      ip_address = instance.public_ip_address
      raise "No public IP address for instance #{instance.id}" unless ip_address.present?
      SNS.instance.subscribe_all_topics!(SNS.instance.sns_endpoint(ip_address))
    end

    @master_instance_id
  end

  def configured?
    Elb.load_balancer.present?
  end

  def register_worker(w)
    retval = load_balancer.instances.register(w.instance.id)
    if @master_instance_id.nil?
      master_instance_id = w.instance.id # handles initialization
    end
    retval
  end

  def deregister_worker(w)
    retval = load_balancer.instances.remove(w.instance.id)
    if @master_instance_id == w.instance.id
      master_instance_id = workers.first.instance.id
    end
    retval
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

  def load_balancer_contains_master?
    load_balancer.exists? ? (load_balancer.instances.map(&:id).include? @master_instance_id): false
  end

  def master_worker
    workers.detect{|w| w.instance.id == master_instance_id}
  end

end
