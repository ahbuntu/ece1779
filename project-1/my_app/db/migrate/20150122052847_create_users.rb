class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :login, null: false
      t.string :password, null: false
      # t.timestamps null: false
    end
  end
end
