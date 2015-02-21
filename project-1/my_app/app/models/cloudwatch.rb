require "aws_boilerplate.rb"

class Cloudwatch
  include Singleton
  include AwsBoilerplate

  def create_alarm(i)
    # TODO: create 1 alarm per newly created instance
    @alarm = @cloudwatch.create(i.concat('-CPU-Utilization'), {
          :namespace => 'EC2',
          :metric_nae => 'CPUUtilization',
          :comparison_operator => 'GreaterThanThreshold',
          :evaluation_periods => 3,
          :period => 300, # in seconds
          :statistic => 'Average',
          :threshold => 75, 
          :actions_enabled => true,
          :alarm_actions => 'arn:aws:sns:us-east-1:460932295327:cpu_threshold', # should be created with ELB
          :alarm_description => 'auto-generated',
          :unit => 'Percent'
          })
  end

  def alarm
    @alarm
  end
  
  def alarms
    # TODO: listing of all alarms configured - may not be required
    self.cloudwatch.alarms.each do |alarm|
      puts alarm.name
    end
  end

end
