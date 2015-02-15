class Manager::WorkersController < ManagerController
  def index
    @elb = elb
    @workers = Worker.all
  end

  def start_elb
    Elb.create_load_balancer
    redirect_to manager_workers_path
  end

  def start_instance
    worker = Worker.launch_instance
    elb.register_instance(worker)
    redirect_to manager_workers_path
  end

  def stop_instance
    instance_id = params[:instance_id]
    worker = Worker.with_id(instance_id)
    raise "Worker cannot be stopped" unless worker.can_stop?

    worker.stop!
    elb.deregister_instance(worker)
    elb.remove_instance(worker)

    redirect_to manager_workers_path
  end

  def terminate_instance
    instance_id = params[:instance_id]
    worker = Worker.with_id(instance_id)
    raise "Worker cannot be stopped" unless worker.can_terminate?

    worker.terminate!
    elb.deregister_instance(worker)
    elb.remove_instance(worker)

    redirect_to manager_workers_path
  end

  private

  def elb
    @elb ||= Elb.instance
  end

end
