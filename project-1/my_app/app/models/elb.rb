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
    Rails.logger.info("workers")
    workers = AWS.memoize do
      load_balancer.instances.map do |i|
        Worker.new(i)
      end
    end rescue []
  end

  def configured?
    Elb.load_balancer.present?
  end

  def register_instance(i)
    load_balancer.instances.register(i)
  end

  def deregister_instance(i)
    load_balancer.instances.deregister(i)
  end

  def remove_instance(i)
    load_balancer.instances.remove(i)
  end

  def name
    load_balancer.name
  end

  def url
    "http://#{load_balancer.dns_name}"
  end

  # returns health status in a hash keyed by instance_id
  def health
    Rails.logger.info("health")
    health = AWS.memoize do
      load_balancer.instances.health.inject({}) do |h,i|
        instance = i[:instance]
        h[instance.id] = i
        h
      end
    end rescue nil
  end

end
