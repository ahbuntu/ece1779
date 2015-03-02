class TestAndRebalanceWorker
  include Sidekiq::Worker
  include AwsBoilerplate

  def perform
    autoscale = AutoScale.instance
    if autoscale.cooling_down?
      Rails.logger.info "[TestAndRebalanceWorker] Still cooling down (until #{autoscale.cooldown_expires_at})..."
    else
      TestAndRebalanceWorker.rebalance_cluster_if_necessary if AutoScale.instance.enabled?
    end
  end
end
