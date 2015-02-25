require "aws_boilerplate.rb"

class Cloudwatch
  include Singleton
  include AwsBoilerplate

  def create_cpu_alarm(type, instance_id, threshold, topic)
    type = type.upcase
    raise "type (#{type}) not supported: expects 'high' or 'low'" unless %w(HIGH LOW).include?(type)

    # TODO: create 1 alarm per newly created instance
    alarm_collection.create("#{instance_id}-#{type.upcase}-CPU-Utilization", 
      {
        :namespace           => 'AWS/EC2',
        :metric_name         => 'CPUUtilization',
        :comparison_operator => (type == 'HIGH' ? 'GreaterThanThreshold' : 'LessThanThreshold'),
        :evaluation_periods  => 3,
        :period              => 5.minutes.to_i, # in seconds
        :statistic           => 'Average',
        :threshold           => threshold, 
        :actions_enabled     => true,
        :alarm_actions       => [topic.arn],
        :alarm_description   => 'auto-generated',
        :unit                => 'Percent',

        # TODO: can we make this the security group and only create one alarm for high & one for low?
        :dimensions          => [{:name => "InstanceId", :value => instance_id}] 
      })
  end

  def update_cpu_alarm(type, instance_id, threshold, topic)
    type = type.upcase
    raise "type (#{type}) not supported: expects 'high' or 'low'" unless %w(HIGH LOW).include?(type)

    alarm_collection["#{instance_id}-#{type.upcase}-CPU-Utilization"].update(
      {
        :namespace           => 'AWS/EC2',
        :comparison_operator => (type == 'HIGH' ? 'GreaterThanThreshold' : 'LessThanThreshold'),
        :evaluation_periods  => 3,
        :period              => 5.minutes.to_i, # in seconds
        :statistic           => 'Average',
        :threshold           => threshold, 
        :actions_enabled     => true,
        :alarm_actions       => [topic.arn],
        :alarm_description   => 'auto-generated',
        :unit                => 'Percent',
      })
  end

  def create_high_cpu_alarm(instance_id, threshold)
    create_cpu_alarm('high', instance_id, threshold, SNS.instance.topic_for_name(SNS::HIGH_CPU_TOPIC_NAME))
  end

  def create_low_cpu_alarm(instance_id, threshold)
    create_cpu_alarm('low', instance_id, threshold, SNS.instance.topic_for_name(SNS::LOW_CPU_TOPIC_NAME))
  end

  def update_high_cpu_alarm(instance_id, threshold)
    update_cpu_alarm('high', instance_id, threshold, SNS.instance.topic_for_name(SNS::HIGH_CPU_TOPIC_NAME))
  end

  def update_low_cpu_alarm(instance_id, threshold)
    update_cpu_alarm('low', instance_id, threshold, SNS.instance.topic_for_name(SNS::LOW_CPU_TOPIC_NAME))
  end
  
  def alarm_collection
    @cw ||= AWS::CloudWatch.new(region: Cloudwatch.default_availability_zone)
    @cw.alarms
  end

  def delete_all_alarms!
    alarm_collection.delete(alarm_collection.map(&:name))
  end

  def alarms_for_instance_id(instance_id)
    alarm_collection.with_name_prefix(instance_id)
  end

  def delete_alarms_for_instance_id!(instance_id)
    alarm_collection.delete(alarms_for_instance_id.map(&:name))
  end

end
