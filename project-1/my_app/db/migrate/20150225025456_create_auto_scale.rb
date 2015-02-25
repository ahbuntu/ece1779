class CreateAutoScale < ActiveRecord::Migration
  def change
    create_table :auto_scales do |t|
      t.float :grow_cpu_thresh
      t.float :shrink_cpu_thresh
      t.float :grow_ratio_thresh
      t.float :shrink_ratio_thresh
      t.boolean :enabled
    end
  end
end
