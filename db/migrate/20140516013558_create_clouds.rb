class CreateClouds < ActiveRecord::Migration
  def up
    create_table :clouds do |t|
      t.string :name
      t.string :cloud_type
      t.string :entry_point
      t.string :key
      t.string :secret
      t.string :tenant_id
      t.timestamps
    end
  end

  def down
    drop_table :clouds
  end
end
