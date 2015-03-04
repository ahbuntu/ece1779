class TerminateWorker
  include Sidekiq::Worker
  include AwsBoilerplate

  def perform(instance_id, terminate_by)
    instance = self.class.all_instances[instance_id]
    if !instance.exists?
      Rails.logger.info "[TerminateWorker] instance #{instance_id} does not exist. Bailing."
      return
    else
      Rails.logger.info "[TerminateWorker] Terminating instance #{instance_id}."
      worker = Worker.new(instance)
      worker.delete_alarms!
      Elb.instance.deregister_worker(worker)
      worker.terminate!
    end
  end
end
