require 'httparty'

class ManagerController < ApplicationController
  skip_before_filter :authenticate
  protect_from_forgery :except => :aws_alarm
  
  def start_worker
    worker = Worker.launch_worker
    elb.register_worker(worker)

    ## this entire block needs to happen ONLY after the instace gets a public IP - so not here. but where?
    # current_workers = Elb.instance.workers
    # if current_workers.size == 1
    #   current_workers.each do |w|
    #     # this should be called only once and only for the very first instance in the ELB (i.e. the master)
    #     SNS.create_topic_subscription(w)
    #   end
    # end
    # CW.create_alarm(worker.instance.id)

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

    AutoScale.grow_cpu_thresh     = params[:cpu_grow_val].to_f
    AutoScale.shrink_cpu_thresh   = params[:cpu_shrink_val].to_f
    AutoScale.grow_ratio_thresh   = params[:ratio_grow_val].to_f
    AutoScale.shrink_ratio_thresh = params[:ratio_shrink_val].to_f

    AutoScale.enabled             = wants_to_enable && AutoScale.valid?

    if wants_to_enable && !AutoScale.valid?
      respond_to do |format|
        format.js { render :js => "alert('Validation Error: #{AutoScale.errors.first}');", :status => 400 }
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
    if @@cooldown_until.present? && @@cooldown_until > Time.now
      Rails.logger.info "[rebalance_cluster] Still cooling down (until #{@cooldown_until})..."
      return
    end

    workers = Worker.all
    cpu = workers.map(&:latest_cpu_utilization)
    return if cpu.size == 0
    avg_cpu = cpu.sum.to_f / cpu.count

    if avg_cpu > AutoScale.grow_cpu_thresh.to_f
      grow_cluster
    elsif avg_cpu < AutoScale.shrink_cpu_thresh.to_f
      shrink_cluster
    end
  end

  def grow_cluster
    @@cooldown_until = 300.seconds.from_now
    # Do some stuff
  end

  def shrink_cluster
    @@cooldown_until = 300.seconds.from_now
    # Do some stuff
  end

end
