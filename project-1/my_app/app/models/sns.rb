require "aws_boilerplate.rb"

class SNS
  include Singleton
  include AwsBoilerplate

  TOPIC_NAME = "cpu_threshold_dev4"

  class << self
    def sns
      @sns ||= AWS::SNS::TopicCollection.new(region: default_availability_zone)
    end

    def create_topic_subscription(w)
      return topic unless topic == nil
      @topic = sns.create(TOPIC_NAME)
      subscribe(w)
    end

    def subscribe(w)
      @active_subscription = topic.subscribe('http://' + w.instance.public_ip_address + '/manager/aws_alarm') 
    end

    def topic
      @topic
    end

    def unsubscribe
      @active_subscription.unsubscribe
    end

    # debugging purposes only
    def topic_nilify
      @topic = nil
    end
  end


end
