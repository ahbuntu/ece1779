require 'httparty'

class ManagerController < ApplicationController
  skip_before_filter    :authenticate
  before_action         :authenticate_manager, :except => [:new, :create]
  protect_from_forgery  :except => :aws_alarm
  
  def new
    redirect_to manager_path if manager_logged_in?
  end

  def create 
    if is_manager?(params["login"], params["password"])
      log_in_manager
      redirect_to manager_path
    else
      # Create an error message.
      flash.now[:danger] = 'Incorrect login/password combination'
      render 'new'
    end
  end

  def destroy
    log_out_manager if manager_logged_in?        
    redirect_to manager_login_path
  end

  def start_worker
    launch_and_register_worker
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
    wants_to_enable = params[:enable_autoscale].to_i == 1

    autoscale = AutoScale.instance

    autoscale.grow_cpu_thresh     = params[:cpu_grow_val].to_f
    autoscale.shrink_cpu_thresh   = params[:cpu_shrink_val].to_f
    autoscale.grow_ratio_thresh   = params[:ratio_grow_val].to_f
    autoscale.shrink_ratio_thresh = params[:ratio_shrink_val].to_f

    autoscale.enabled             = wants_to_enable

    if !autoscale.save
      respond_to do |format|
        format.js { render :js => "alert('Validation Error: #{autoscale.errors.full_messages.to_sentence}');", :status => 400 }
      end
    else
      respond_to do |format|
        format.js   {render :layout => false}
      end
    end
  end

  # TODO: this could use some security since anything can POST to it...
  def aws_alarm
    # taken from: http://tech.xogroupinc.com/post/79166302844/creating-sns-subscription-endpoints-with-ruby-on
    
    # get amazon message type and topic
    amz_message_type = request.headers['x-amz-sns-message-type']
    amz_sns_topic = request.headers['x-amz-sns-topic-arn']

    # return unless !amz_sns_topic.nil? &&
    #   amz_sns_topic.to_s.downcase ==  'arn:aws:sns:us-east-1:460932295327:cpu_threshold'

    return unless amz_sns_topic.present?
    Rails.logger.info "[AWS ALARM] Received for topic #{amz_sns_topic} (type: #{amz_message_type})"

    request_body = JSON.parse request.body.read
    Rails.logger.info "[AWS ALARM] Request body: #{request_body}"

    # if this is the first time confirmation of subscription, then confirm it
    if amz_message_type.to_s.downcase == 'subscriptionconfirmation'
      send_subscription_confirmation request_body
      head status: :accepted and return
    end

    if amz_message_type.to_s.downcase == 'notification'
      #TODO: implement auto-scaling logic based on alarm and auto-scale config
      #do_work request_body

      rebalance_cluster
    end
    head status: :accepted
  end

  private

  def launch_and_register_worker
    worker = Worker.launch_worker
    elb.register_worker(worker)
    worker
  end

  def elb
    @elb ||= Elb.instance
  end

  def cw
    @cw ||= CW.instance
  end

  def send_subscription_confirmation(request_body)
    subscribe_url = request_body['SubscribeURL']
    return nil unless !subscribe_url.to_s.empty? && !subscribe_url.nil?
    subscribe_confirm = HTTParty.get subscribe_url
  end

  ###
  # TODO: move this into a service

  # Also, do we care about serializing all this on a single thread? There's
  # a small chance of a race condition if 2+ notifications come in at the same
  # time.
  def rebalance_cluster
    autoscale = AutoScale.instance
    if autoscale.cooling_down?
      Rails.logger.info "[rebalance_cluster] Still cooling down (until #{autoscale.cooldown_expires_at})..."
      return
    end

    workers = Worker.all
    cpu = workers.map(&:latest_cpu_utilization)
    return if cpu.size == 0
    avg_cpu = cpu.sum.to_f / cpu.count

    if avg_cpu > autoscale.grow_cpu_thresh.to_f
      grow_cluster
    elsif avg_cpu < autoscale.shrink_cpu_thresh.to_f
      shrink_cluster
    end
  end

  def grow_cluster
    autoscale = AutoScale.instance
    autoscale.start_cooldown! || return # bail if already cooling down

    start_size = Elb.instance.workers.size
    target_size = [(start_size * autoscale.grow_ratio_thresh.to_f).to_i, autoscale.max_instances].min
    
    Rails.logger.info "[grow_cluster] From #{start_size} to #{target_size}"

    while start_size <= target_size
      if !autoscale.cooling_down? # paranoia
        raise "Cooldown expired while growing cluster!"
      end
      worker = launch_and_register_worker # NOTE: this might fail if we hit the AWS limit
      Rails.logger.info "Launching instance #{worker.instance.id}"
      start_size += 1
    end
  end

  def shrink_cluster
    autoscale = AutoScale.instance
    autoscale.start_cooldown! || return # bail if already cooling down

    start_size = Elb.instance.workers.size
    target_size = (start_size / autoscale.shrink_ratio_thresh.to_f).to_i
    target_size = 1 if target_size == 0
    
    Rails.logger.info "[shrink_cluster] From #{start_size} to #{target_size}"

    elb = Elb.instance

    elb.workers.each do |worker|
      return if start_size <= target_size

      if !autoscale.cooling_down? # paranoia
        raise "Cooldown expired while shrinking cluster!"
      end

      # This assumes that shrink_cluster is never called by an instance that is going to be terminated
      # I.e. it is only called on the master_instance
      if worker.can_terminate? && worker.instance.id != elb.master_instance_id
        Rails.logger.info "Terminating instance #{worker.instance.id}"
        worker.terminate!
        elb.deregister_worker(worker)
        elb.remove_worker(worker)
        cw.delete_alarm(worker.instance.id)
        start_size -= 1
      end
    end
  end

end
