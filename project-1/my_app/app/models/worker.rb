class Worker
  attr_reader :name, :instance_id, :image_id

  def initialize(name, instance_id, image_id)
    @name = name
    @instance_id = instance_id
    @image_id = image_id
  end

  private

  def cloudwatch
    @cloudwatch ||= Aws::CloudWatch::Client.new(region: default_availability_zone)
  end

  def cpu
    AWS::CloudWatch::Metric.new( 'AWS/EC2', 'CPUUtilization', :dimensions => [])
  end
end