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

  def image_stats
    @elb = elb
    @workers = @elb.workers # Worker.all
    @health = @elb.health
    render :layout => false
  end

  def elb_status
    @elb = elb
    render :layout => false
  end

  def worker_status
    @elb = elb
    @workers = @elb.workers # Worker.all
    @health = @elb.health
    render :layout => false
  end

  def auto_scale
    AutoScale.set_options(params[:cpu_grow_threshold], params[:cpu_shrink_threshold], 
      params[:ratio_grow_threshold], params[:ratio_shrink_threshold])
  
    respond_to do |format|
      format.js   {render :layout => false}
    end
  end

  private

  def elb
    @elb ||= Elb.instance
  end

end
