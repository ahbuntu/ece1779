class Manager::WorkersController < ManagerController
  def index
    @workers = instances

    # AWS::EC2::Errors::AuthFailure
    # AWS::EC2::Errors::ServiceError

    # @workers << Worker.new("foo")
  end

  private

  # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html
  def ec2
    @ec2 ||= AWS::EC2::Client.new(region: default_availability_zone)
  end

  # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#describe_instances-instance_method
  def instances
    ec2.describe_instances(:dry_run => true)
  end

  def default_image_id
    # use DescribeImages to get the AMI of the master
  end

  def default_availability_zone
    'us-east-1'
  end

  def default_instance_type
    'm1.small'
  end

  # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#run_instances-instance_method
  def launch_instance(image_id = default_image_id, min_count = 1, max_count = 1, options = {})
    options[:monitoring] ||= {}
    options[:monitoring][:enabled] = true

    options[:placement][:availability_zone] = default_availability_zone

    options[:instance_type] = default_instance_type

    raise "TODO"
  end

  def start_instance(instance)
    ec2.start_instances(:instance_ids => [instance])
    # elb.register_instances_with_load_balancer
  end

  def terminate_instance(instance)
    ec2.terminate_instances(:instance_ids => [instance])
  end

  def stop_instance(instance)
    ec2.stop_instances(:instance_ids => [instance])
  end

  # http://docs.aws.amazon.com/sdkforruby/api/Aws/ElasticLoadBalancing.html
  #
  # "When an instance registered with a load balancer is stopped and then restarted, 
  # the IP addresses associated with the instance changes. Elastic Load Balancing 
  # cannot recognize the new IP address, which prevents it from routing traffic 
  # to the instances. We recommend that you de-register your Amazon EC2 instances 
  # from your load balancer after you stop your instance, and then register the 
  # load balancer with your instance after you've restarted. To de-register your 
  # instances from load balancer, use DeregisterInstancesFromLoadBalancer action."
  def elb
    # rescue Aws::ElasticLoadBalancing::Errors::ServiceError
    @elb ||= AWS::ElasticLoadBalancing::Client.new(region: default_availability_zone)
  end

  def create_elb
    # elb.create_load_balancer(...)
  end

  def elb_health
    elb.describe_instance_health
  end

  def elb_status
    elb.describe_load_balancers
  end

end
