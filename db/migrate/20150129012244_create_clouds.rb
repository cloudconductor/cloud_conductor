class CreateClouds < ActiveRecord::Migration
  def change
    create_table :clouds do |t|
      t.references :project
      t.string :name
      t.string :description
      t.string :type
      t.string :entry_point
      t.string :key
      t.string :secret
      t.string :tenant_name
      t.timestamps null: false
    end
  end
end
