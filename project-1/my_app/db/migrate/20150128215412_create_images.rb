class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.integer :userId
      t.string :key1
      t.string :key2
      t.string :key3
      t.string :key4
      # t.timestamps null: false
    end
  end
end
