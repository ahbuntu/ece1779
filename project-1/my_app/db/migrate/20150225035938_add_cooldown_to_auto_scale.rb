class AddCooldownToAutoScale < ActiveRecord::Migration
  def change
    add_column :auto_scales, :cooldown_period_in_seconds, :integer, :default => 0
    add_column :auto_scales, :cooldown_expires_at, :datetime
  end
end
