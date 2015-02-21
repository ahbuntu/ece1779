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
    AutoScale.set_values(params[:cpu_grow_val], params[:cpu_shrink_val], 
      params[:ratio_grow_val], params[:ratio_shrink_val])

    print AutoScale.grow_cpu_thresh
    respond_to do |format|
      format.js   {render :layout => false}
    end
  end

  def aws_alarm
    # taken from: http://tech.xogroupinc.com/post/79166302844/creating-sns-subscription-endpoints-with-ruby-on
    
    # get amazon message type and topic
    amz_message_type = request.headers['x-amz-sns-message-type']
    amz_sns_topic = request.headers['x-amz-sns-topic-arn']

    return unless !amz_sns_topic.nil? &&
      amz_sns_topic.to_s.downcase ==  'arn:aws:sns:us-east-1:460932295327:cpu_threshold'

    request_body = JSON.parse request.body.read

    # if this is the first time confirmation of subscription, then confirm it
    if amz_message_type.to_s.downcase == 'subscriptionconfirmation'
        send_subscription_confirmation request.body
        return
    end

    if amz_message_type.to_s.downcase == 'notification'
      #TODO: implement auto-scaling logic based on alarm and auto-scale config
      #do_work request_body
    end
    render :layout => false
  end


  private

  def elb
    @elb ||= Elb.instance
  end

  def send_subscription_confirmation(request_body)
    subscribe_url = request_body['SubscribeURL']
    return nil unless !subscribe_url.to_s.empty? && !subscribe_url.nil?
    subscribe_confirm = HTTParty.get subscribe_url
end

end
