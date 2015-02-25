class AddMaxInstancesToAutoScale < ActiveRecord::Migration
  def change
    add_column :auto_scales, :max_instances, :integer, :default => 10
  end
end
