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

    def all_instances
      ec2.instances
    end

    def all_running_instances
      all_instances.select{|i| i.status == :running}
    end

    def instances_for_ami_id(ami_id)
      Rails.logger.info("instances_for_ami_id")
      instances = AWS.memoize do
        ec2.instances.select do |i|
          i.image.id == ami_id
        end
      end
    end

    def cloudwatch_client
      @cloudwatch_client ||= AWS::CloudWatch::Client.new(region: default_availability_zone)
    end

    # Do we care about serializing all this on a single thread? There's
    # a small chance of a race condition if 2+ notifications come in at the same
    # time.
    def rebalance_cluster_if_necessary
      autoscale = AutoScale.instance
      if autoscale.cooling_down?
        Rails.logger.info "[rebalance_cluster_if_necessary] Still cooling down (until #{autoscale.cooldown_expires_at})..."
        return
      end

      workers = Worker.all
      cpu = workers.map(&:latest_cpu_utilization)

      if cpu.size == 0
        Rails.logger.error "[rebalance_cluster_if_necessary] No CPUs? Bailing"
        return
      end

      avg_cpu = cpu.sum.to_f / cpu.count

      Rails.logger.info "[rebalance_cluster_if_necessary] avg_cpu = #{avg_cpu}"

      if avg_cpu > autoscale.grow_cpu_thresh.to_f
        Rails.logger.info "[rebalance_cluster_if_necessary] -> grow_cluster."
        grow_cluster
      elsif avg_cpu < autoscale.shrink_cpu_thresh.to_f
        Rails.logger.info "[rebalance_cluster_if_necessary] -> shrink_cluster."
        shrink_cluster
      else
        Rails.logger.info "[rebalance_cluster_if_necessary] No action to be taken."
      end
    end

    def grow_cluster(target_size = nil)
      autoscale = AutoScale.instance
      start_size = Elb.instance.workers.size

      target_size ||= (start_size * autoscale.grow_ratio_thresh.to_f).to_i
      target_size = [target_size, autoscale.max_instances].min
      
      if start_size >= target_size
        Rails.logger.info "[grow_cluster] start_size (#{start_size}) >= target_size (#{target_size}). Skipping"
        return
      end

      autoscale.start_cooldown! # || return # bail if already cooling down
      Rails.logger.info "[grow_cluster] From #{start_size} to #{target_size}"

      while start_size < target_size
        if !autoscale.cooling_down? # paranoia
          raise "Cooldown expired while growing cluster!"
        end
        worker = launch_and_register_worker # NOTE: this might fail if we hit the AWS limit
        Rails.logger.info "[grow_cluster] Launching instance #{worker.instance.id}"
        start_size += 1
      end
      Rails.logger.info "[grow_cluster] DONE."
    end

    # Helper to get the current EC2 instance_id
    # See http://stackoverflow.com/questions/625644/find-out-the-instance-id-from-within-an-ec2-machine
    def my_instance_id
      if @my_instance_id == nil
        metadata_endpoint = 'http://169.254.169.254/latest/meta-data/' + 'instance-id'
        h = HTTParty.get(metadata_endpoint)
        @my_instance_id = (h.response.code.to_i == 200 ? h.response.body : nil)
      end
      @my_instance_id
    end

    def shrink_cluster(target_size = nil)
      autoscale = AutoScale.instance

      start_size = Elb.instance.workers.size
      target_size ||= (start_size / autoscale.shrink_ratio_thresh.to_f).to_i
      target_size = 1 if target_size == 0

      if start_size <= target_size
        Rails.logger.info "[shrink_cluster] start_size (#{start_size}) <= target_size (#{target_size}). Skipping"
        return
      end

      autoscale.start_cooldown! # || return # bail if already cooling down      
      Rails.logger.info "[shrink_cluster] From #{start_size} to #{target_size}"

      elb = Elb.instance

      elb.workers.each do |worker|
        return if start_size <= target_size

        if worker.instance.id == my_instance_id
          Rails.logger.info "[shrink_cluster] Skipping instance #{my_instance_id} because it's me!"
          return
        end

        if !autoscale.cooling_down? # paranoia
          raise "Cooldown expired while shrinking cluster!"
        end

        # This assumes that shrink_cluster is never called by an instance that is going to be terminated
        if worker.can_terminate?
          Rails.logger.info "[shrink_cluster] Removing instance #{worker.instance.id}"
          worker.delete_alarms!
          elb.deregister_worker(worker)
          start_size -= 1

          # instead of outright terminating the worker, we give it time to drain the image upload/processing jobs
          DrainQueueAndTerminateWorker.perform_async(worker.instance.id, Time.now + 3.minutes)
        else
          Rails.logger.info "[shrink_cluster] worker (#{worker.instance.id} cannot terminate."
        end
      end
      Rails.logger.info "[shrink_cluster] DONE."
    end

    def launch_and_register_worker
      disable_api_termination = false # any instance can be easily terminated
      worker = Worker.launch_worker(true, disable_api_termination)
      Elb.instance.register_worker(worker)
      worker
    end
  end

end
