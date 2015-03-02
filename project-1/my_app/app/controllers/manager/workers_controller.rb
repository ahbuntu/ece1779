class Manager::WorkersController < ManagerController
  skip_before_filter :authenticate

  def index
    @autoscale = AutoScale.instance
  end

  def stop_worker
    instance_id = params[:worker_id]
    worker = Worker.with_id(instance_id)
    raise "Worker cannot be stopped" unless worker.can_stop?

    worker.stop!
    elb.deregister_worker(worker)
    
    redirect_to manager_workers_path
  end

  def terminate_worker
    instance_id = params[:worker_id]
    worker = Worker.with_id(instance_id)
    raise "Worker cannot be terminated" unless worker.can_terminate?
    TerminateWorker.perform_in(5.seconds, instance_id) # in case we're terminating ourselves
    elb.deregister_worker(worker)
    redirect_to manager_workers_path
  end
end
