class AddExtensionToImage < ActiveRecord::Migration
  def change
    add_column :images, :extension, :string, :limit => 10
  end
end
