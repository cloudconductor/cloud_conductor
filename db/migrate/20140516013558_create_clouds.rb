class CreateClouds < ActiveRecord::Migration
  def up
    create_table :clouds do |t|
      t.string :name
      t.string :cloud_type
      t.string :cloud_entry_point_url
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
