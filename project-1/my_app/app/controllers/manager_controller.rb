require 'httparty'

class ManagerController < ApplicationController
  include AwsBoilerplate

  skip_before_filter    :authenticate
  before_action         :authenticate_manager, :except => [:new, :create, :aws_alarm]
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
    disable_api_termination = false
    worker = Worker.launch_worker(true, disable_api_termination)
    Elb.instance.register_worker(worker)
    redirect_to manager_workers_path
  end

  def start_elb
    Elb.create_load_balancer
    add_all_running_instances_to_elb!
    redirect_to manager_workers_path
  end

  def reset_alarms
    Elb.instance.reset_alarm_subscriptions!
  end

  def purge_images
    Image.delete_all
    # Image.s3_bucket.objects.delete_all
    Image.s3_bucket.clear!
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
    autoscale = AutoScale.instance
    autoscale.update_attributes(autoscale_params)
    if !autoscale.save
      respond_to do |format|
        # FIXME: move this into a partial
        format.js { render :js => "alert('Validation Error: #{autoscale.errors.full_messages.to_sentence}'); $('#form-autoscale .spinner').hide();", :status => 400 }
      end
    else
      update_cw_alarms
      respond_to do |format|
        format.js  { render :layout => false }
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
      # TODO: implement auto-scaling logic based on alarm and auto-scale config
      self.class.rebalance_cluster_if_necessary if AutoScale.instance.enabled?
    end
    head status: :accepted
  end

  private

  def add_all_running_instances_to_elb!
    instances = self.class.all_running_instances.select{|i| i.status == :running}
    elb = Elb.instance

    instances.each do |i|
      Rails.logger.info "Adding Instance #{i.id} to ELB"
      w = Worker.new(i)
      elb.register_worker(w)
    end
  end

  def update_cw_alarms
    autoscale = AutoScale.instance
    cw ||= Cloudwatch.instance
    if autoscale.enabled?
      cw.update_all_high_cpu_alarms(elb.workers, autoscale.grow_cpu_thresh) 
      cw.update_all_low_cpu_alarms(elb.workers, autoscale.shrink_cpu_thresh) 
    else 
      cw.update_all_high_cpu_alarms(elb.workers, 100.0)
      cw.update_all_low_cpu_alarms(elb.workers, 0.0)
    end
  end

  def elb
    @elb ||= Elb.instance
  end

  def send_subscription_confirmation(request_body)
    subscribe_url = request_body['SubscribeURL']
    return nil unless !subscribe_url.to_s.empty? && !subscribe_url.nil?
    subscribe_confirm = HTTParty.get subscribe_url
  end

  ###
  # TODO: move this into a service

  def autoscale_params
    params.require(:auto_scale).permit(:grow_cpu_thresh, :shrink_cpu_thresh, :grow_ratio_thresh, :shrink_ratio_thresh, :enabled, :max_instances)
  end

end
