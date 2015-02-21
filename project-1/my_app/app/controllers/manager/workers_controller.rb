class Manager::WorkersController < ManagerController
  skip_before_filter :authenticate

  def index
  end

  def stop_worker
    instance_id = params[:worker_id]
    worker = Worker.with_id(instance.id)
    raise "Worker cannot be stopped" unless worker.can_stop?

    worker.stop!
    elb.deregister_instance(worker.instance.id)
    elb.remove_instance(worker.instance.id)

    redirect_to manager_workers_path
  end

  def terminate_worker
    instance_id = params[:worker_id]
    worker = Worker.with_id(instance.id)
    raise "Worker cannot be stopped" unless worker.can_terminate?

    worker.terminate!
    elb.deregister_instance(worker.instance.id)
    elb.remove_instance(worker.instance.id)
    cw.delete_alarm(worker.instance.id)

    redirect_to manager_workers_path
  end

end
