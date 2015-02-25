require "aws_boilerplate.rb"

class Worker

  include AwsBoilerplate

  attr_reader :instance

  AMI_IMAGE_ID="ami-5e1b4c36" # name: "ece1779-puma-003"

  # NOTE: this can include terminated workers
  def self.all
    instances_for_ami_id(AMI_IMAGE_ID).map do |i|
      Worker.new(i)
    end
  end

  def self.with_id(id)
    all.detect do |w|
      w.instance.id == id
    end
  end

  def self.launch_worker(with_detailed_monitoring = false)
    raise "Default image does not exist (#{default_image.id})" unless default_image.exists?

    # TODO: add support for with_detailed_monitoring
    raise "with_detailed_monitoring not supported" if with_detailed_monitoring

    instance = ec2.instances.create(
      :image_id        => default_image.id,
      :instance_type   => default_instance_type,
      :count           => 1, 
      :security_groups => security_group, 
      :key_pair        => key_pair)

    Rails.logger.info "Launching instance #{instance.id}"
    w = Worker.new(instance)
    w.create_alarms! unless w.terminated?
    w
  end

  def self.security_group
    return @websvr unless @websvr == nil

    @websvr = ec2.security_groups.detect{|w| w.name == "webservers"}
    @websvr ||= ec2.security_groups.create('webservers')

    @websvr.authorize_ingress(:tcp, 80)
    @websvr.authorize_ingress(:tcp, 22)
    @websvr.authorize_ingress(:tcp, 3306)
    @websvr.allow_ping
    @websvr
  rescue AWS::EC2::Errors::InvalidPermission::Duplicate => e
    @websvr
  end

  def self.default_image
    @default_image ||= ec2.images[AMI_IMAGE_ID]
  end

  def self.default_instance_type
    't2.small'
  end

  def initialize(instance)
    @instance = instance
    instance
  end

  def latest_cpu_utilization
    sorted_historical_cpu_utilization_samples.last[:average] rescue nil
  end

  # [:running, :stopped, :shutting_down, :terminated]
  def status
    instance.status
  end

  def can_stop?
    status == :running
  end

  def can_terminate?
    status == :running || status == :stopped
  end

  def terminated?
    status == :terminated
  end

  def stopped?
    status == :stopped
  end

  def running?
    status == :running
  end

  def stop!
    Rails.logger.info "Stopping instance #{instance.id}"
    instance.stop
  end

  def terminate!
    Rails.logger.info "Terminating instance #{instance.id}"
    instance.terminate
  end

  # TODO: Dave to review [move this to the model layer. This isn't exactly "safe"]
  def safe_to_stop?
    workers = Elb.instance.workers
    can_stop? && workers.select{|w| w.running?}.size >= 2
  end

  # TODO: Dave to review [move this to the model layer. This isn't exactly "safe"]
  def safe_to_terminate?
    workers = Elb.instance.workers
    can_terminate? && workers.select{|w| w.running?}.size >= 2
  end

  def create_alarms!
    cw = Cloudwatch.instance
    high_cpu = cw.create_high_cpu_alarm(instance.id, 85)
    low_cpu  = cw.create_low_cpu_alarm(instance.id, 15)
    [high_cpu, low_cpu]
  end

  def delete_alarms!
    cw = Cloudwatch.instance
    cw.delete_alarms_for_instance_id!(instance.id)
  end

  private

  def cpu_metric
    @metric ||= AWS::CloudWatch::Metric.new( 'AWS/EC2', 'CPUUtilization', :dimensions => [{:name => "InstanceId", :value => instance.id}])
  end

  def sorted_historical_cpu_utilization_samples(start_time = 10.minutes.ago)
    historical_cpu_utilization_samples(start_time).sort{|a,b| a[:timestamp] <=> b[:timestamp]}
  end

  def historical_cpu_utilization_samples(start_time)
    stats = cpu_metric.statistics(
      :start_time => start_time,
      :end_time   => Time.now,
      :statistics => ['Average']
    )

    # stats.label #=> 'some-label'
    stats.map do |datapoint|
      # datapoint is a hash
      # ex. {:timestamp=>2015-02-15 16:02:00 UTC, :unit=>"Percent", :average=>0.836}
      datapoint
    end
  end

end