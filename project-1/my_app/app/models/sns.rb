require "aws_boilerplate.rb"

class SNS
  include Singleton
  include AwsBoilerplate

  HIGH_CPU_TOPIC_NAME = "cpu_threshold_high2"
  LOW_CPU_TOPIC_NAME = "cpu_threshold_low2"

  def topic_names
    [HIGH_CPU_TOPIC_NAME, LOW_CPU_TOPIC_NAME]
  end

  def topic_collection
    @topic_collection ||= AWS::SNS::TopicCollection.new(region: SNS.default_availability_zone)
  end

  def topic_for_name(name)
    find_of_create_topic!(name)
  end

  def topics
    # ignore topics that have other names
    topic_names.map do |n|
      topic_for_name(n)
    end
  end

  def find_of_create_topic!(name)
    # it's safe to try to create them again: AWS de-duplicates things
    topic_collection.create(name)
  end

  def subscribe_all_topics!(endpoint)
    topics.each do |t|
      t.subscribe(endpoint, json: true)
    end
  end

  def unsubscribe_all_topics!
    topics.each do |t|
      t.subscriptions.each do |s|
        # For some reason, the SDK won't let us delete PENDING subscriptions.
        # This is by design (in AWS, not just the Ruby SDK). PENDING subs
        # automatically expire after 3 days.
        s.exists? && s.unsubscribe
      end
    end
  end

  def sns_endpoint(ip_address)
    "http://" + ip_address + "/manager/aws_alarm"
  end
end
