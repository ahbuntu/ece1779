class DrainQueueAndTerminateWorker
  include Sidekiq::Worker
  include AwsBoilerplate

  # This expects to be executed on the instance being terminated
  # I.e. the Sidekiq queue is also local.
  #
  # ALSO: it assumes that all alarm deletion and ELB deregistration has already been handled.
  def perform(instance_id, terminate_by)
    instance = self.class.all_instances[instance_id]
    if !instance.exists?
      Rails.logger.info "[DrainQueueAndTerminateWorker] instance #{instance_id} does not exist. Bailing."
      return
    elsif Time.now >= terminate_by
      Rails.logger.info "[DrainQueueAndTerminateWorker] Terminating instance #{instance.id}"
      instance.terminate
      return
    end

    retry_queue = Sidekiq::RetrySet.new
    retry_queue.retry_all

    if Sidekiq::Queue.all.map(&:size).sum == 0 # doesn't count scheduled jobs
      Rails.logger.info "[DrainQueueAndTerminateWorker] Terminating instance #{instance.id}"
      instance.terminate # no jobs left
    else
      DrainQueueAndTerminateWorker.perform_in(30.seconds, instance_id, terminate_by)
    end
  end
end
