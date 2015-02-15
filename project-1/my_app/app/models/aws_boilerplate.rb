module AwsBoilerplate
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def default_availability_zone
      'us-east-1'
    end

    def my_images
      ec2.images.with_owner("self")
    end

    def key_pair
      @key_pair ||= ec2.key_pairs.first
    end

    def ec2
      @ec2 ||= AWS::EC2.new(region: default_availability_zone)

      # TODO: test connection and catch these exceptions:
      # AWS::EC2::Errors::AuthFailure
      # AWS::EC2::Errors::ServiceError
    end

    def instances_for_ami_id(ami_id)
      ec2.instances.select do |i|
        i.image.id == ami_id
      end
    end

    def cloudwatch
      @cloudwatch ||= Aws::CloudWatch::Client.new(region: default_availability_zone)
    end
  end
end
