class ManagerController < ApplicationController

  def start_worker
    worker = Worker.launch_worker
    elb.register_instance(worker.instance.id)
    redirect_to manager_workers_path
  end

  def start_elb
    Elb.create_load_balancer
    redirect_to manager_workers_path
  end

  private

  def elb
    @elb ||= Elb.instance
  end

end
