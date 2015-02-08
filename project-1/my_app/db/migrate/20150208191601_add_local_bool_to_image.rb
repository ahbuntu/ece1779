class AddLocalBoolToImage < ActiveRecord::Migration
  def change
    add_column :images, :uuid, :string, :limit => 36
  end
end
