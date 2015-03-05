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
      TestAndRebalanceWorker.rebalance_cluster_if_necessary if autoscale.enabled?
    end
  end
end
