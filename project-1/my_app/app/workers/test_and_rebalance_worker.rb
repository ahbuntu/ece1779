class TestAndRebalanceWorker
  include Sidekiq::Worker
  include AwsBoilerplate
  sidekiq_options :queue => :critical

  def perform
    autoscale = AutoScale.instance
    if autoscale.cooling_down?
      Rails.logger.info "[TestAndRebalanceWorker] Still cooling down (until #{autoscale.cooldown_expires_at})..."
    else
      Rails.logger.info "[TestAndRebalanceWorker] Rebalancing cluster if necessary"
      Rails.logger.info "[AUTOSCALE RECREATE ALARMS] Creating and updating alarms on cooldown expiry "
      if autoscale.enabled?
        elb ||= Elb.instance
        elb.workers.each{|w| w.create_alarms!}
        cw ||= Cloudwatch.instance
        cw.update_all_high_cpu_alarms(elb.workers, autoscale.grow_cpu_thresh) 
        cw.update_all_low_cpu_alarms(elb.workers, autoscale.shrink_cpu_thresh) 
      end
      TestAndRebalanceWorker.rebalance_cluster_if_necessary if autoscale.enabled?
    end
  end
end
