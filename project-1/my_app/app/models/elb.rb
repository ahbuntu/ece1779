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

  def reset_alarms!
    # Initialize and point SNS subscriptions to the ELB
    SNS.instance.unsubscribe_all_topics!

    dns_name = load_balancer.dns_name
    raise "No DNS name for ELB" unless dns_name.present?
    SNS.instance.subscribe_all_topics!(SNS.instance.sns_endpoint(dns_name))
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
    w.create_alarms! # paranoia, but that's fine. OR IS IT?!
  end

  def deregister_worker(w)
    load_balancer.instances.remove(w.instance.id)
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
