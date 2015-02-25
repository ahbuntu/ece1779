class AutoScale < ActiveRecord::Base

  include ActiveRecord::Singleton

  validates :enabled, :inclusion => { :in => [1, 0] }
  validates_numericality_of :grow_cpu_thresh, less_than_or_equal_to: 100.0
  validates_numericality_of :shrink_cpu_thresh, greater_than_or_equal_to: 0.0
  validate :grow_gt_shrink
  validates_numericality_of :grow_ratio_thresh, greater_than_or_equal_to: 1.0
  validates_numericality_of :shrink_ratio_thresh, greater_than_or_equal_to: 1.0

  validates_numericality_of :cooldown_period_in_seconds, greater_than_or_equal_to: 0

  before_validation :set_defaults

  def enabled?
    enabled.to_i == 1
  end

  def cooling_down?
    self.cooldown_expires_at.present? && self.cooldown_expires_at > Time.now
  end

  def start_cooldown!
    unless cooling_down?
      update_attribute(:cooldown_expires_at, self.cooldown_period_in_seconds.seconds.from_now)
    end
  end

  private

  def grow_gt_shrink
    if grow_cpu_thresh.present? && shrink_cpu_thresh.present? && grow_cpu_thresh <= shrink_cpu_thresh
      errors.add(:grow_cpu_thresh, 'Growth threshold must be > shrink threshold')
    end
  end

  def set_defaults
    self.grow_cpu_thresh ||= 100.0
    self.shrink_cpu_thresh ||= 0.0
    self.grow_ratio_thresh ||= 1.0
    self.shrink_ratio_thresh ||= 1.0
    self.cooldown_period_in_seconds ||= 5.minutes.to_i
    self.enabled = false
    true
  end

end
