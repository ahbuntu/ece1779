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

  def master_worker
    @master_worker
  end

  def master_worker=(value)
    return value if @master_worker == value

    # Initialize and point SNS subscriptions to master_worker
    SNS.instance.unsubscribe_all_topics!

    @master_worker = value
    if @master_worker.present?
      ip_address = @master_worker.instance.public_ip_address
      raise "No public IP address for instance #{@master_worker.instance.id}" unless ip_address.present?
      SNS.instance.subscribe_all_topics!(SNS.instance.sns_endpoint(ip_address))
    end

    @master_worker
  end

  def configured?
    Elb.load_balancer.present?
  end

  def register_worker(w)
    retval = load_balancer.instances.register(w.instance.id)
    if master_worker.nil?
      master_worker = w # handles initialization
    end
    retval
  end

  def deregister_worker(w)
    retval = load_balancer.instances.deregister(w.instance.id)
    if master_worker == w
      master_worker = workers.first
    end
    retval
  end

  def remove_worker(w)
    retval = load_balancer.instances.remove(w.instance.id)
    if master_worker == w
      master_worker = workers.first
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

end
