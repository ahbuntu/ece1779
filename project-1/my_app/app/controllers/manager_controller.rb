class ManagerController < ApplicationController

  def start_worker
    worker = Worker.launch_worker
    elb.register_instance(worker.instance_id)
    redirect_to manager_workers_path
  end

  def start_elb
    Elb.create_load_balancer
    redirect_to manager_workers_path
  end

end
