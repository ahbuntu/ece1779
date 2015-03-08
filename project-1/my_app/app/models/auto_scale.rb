class AutoScale < ActiveRecord::Base

  include ActiveRecord::Singleton

  validates :enabled, :inclusion => { :in => [1, 0] }
  validates_numericality_of :grow_cpu_thresh, less_than_or_equal_to: 100.0
  validates_numericality_of :shrink_cpu_thresh, greater_than_or_equal_to: 0.0
  validate :grow_gt_shrink
  validates_numericality_of :grow_ratio_thresh, greater_than_or_equal_to: 1.0
  validates_numericality_of :shrink_ratio_thresh, greater_than_or_equal_to: 1.0
  validates_numericality_of :max_instances, greater_than_or_equal_to: 1
  validates_numericality_of :max_instances, less_than_or_equal_to: 20  # http://aws.amazon.com/ec2/faqs/#How_many_instances_can_I_run_in_Amazon_EC2
  validates_numericality_of :cooldown_period_in_seconds, greater_than_or_equal_to: 0

  before_validation :set_defaults, on: :create
  before_save :test_alarms_if_being_enabled

  def enabled?
    enabled.to_i == 1
  end

  def cooling_down?
    self.cooldown_expires_at.present? && self.cooldown_expires_at > Time.now
  end

  def start_cooldown!
    unless cooling_down?
      expire_at = self.cooldown_period_in_seconds.seconds.from_now
      update_attribute(:cooldown_expires_at, expire_at)

      # There might be an active alarm when the cooldown expires, so check.
      TestAndRebalanceWorker.perform_at(expire_at + 5.seconds)
    end
  end

  private

  def test_alarms_if_being_enabled
    if self.enabled == 1 && self.enabled_was == 0
      TestAndRebalanceWorker.perform_in(5.seconds)
    end
    true
  end

  def grow_gt_shrink
    if grow_cpu_thresh.present? && shrink_cpu_thresh.present? && grow_cpu_thresh <= shrink_cpu_thresh
      errors.add(:grow_cpu_thresh, 'Growth threshold must be > shrink threshold')
    end
  end

  def set_defaults
    self.grow_cpu_thresh = 100.0
    self.shrink_cpu_thresh = 0.0
    self.grow_ratio_thresh = 1.0
    self.shrink_ratio_thresh = 1.0
    self.cooldown_period_in_seconds = 6.minutes.to_i
    self.max_instances = 10
    self.enabled = false
    true
  end

end
