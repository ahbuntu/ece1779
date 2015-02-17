class ManagerController < ApplicationController
  skip_before_filter :authenticate
  
  def start_worker
    worker = Worker.launch_worker
    elb.register_instance(worker.instance.id)
    redirect_to manager_workers_path
  end

  def start_elb
    Elb.create_load_balancer
    redirect_to manager_workers_path
  end

  def purge_images
    Image.delete_all
    Image.s3_bucket.objects.delete_all
    redirect_to manager_workers_path
  end

  private

  def elb
    @elb ||= Elb.instance
  end

end
