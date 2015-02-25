class DrainQueueAndTerminateWorker
  include Sidekiq::Worker

  # This expects to be executed on the instance being terminated
  # I.e. the Sidekiq queue is also local
  def perform(instance_id, terminate_by)
    worker = Worker.with_id(instance_id)
    if worker.nil?
      return
    elsif Time.now >= terminate_by
      worker.terminate!
      return
    end

    retry_queue = Sidekiq::RetrySet.new
    retry_queue.retry_all

    if Sidekiq::Queue.all.map(&:size).sum == 0 # doesn't count scheduled jobs
      worker.terminate! # no jobs left!
    else
      DrainQueueAndTerminateWorker.perform_in(30.seconds, instance_id, terminate_by)
    end
  end
end
