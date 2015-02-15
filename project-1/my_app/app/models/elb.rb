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
      @load_balancer ||= elb.load_balancers["my-load-balancer"]
      @load_balancer = nil unless @load_balancer.exists?
      @load_balancer
    end
  end

  def load_balancer
    Elb.load_balancer
  end

  def instances
    load_balancer.instances
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

end
