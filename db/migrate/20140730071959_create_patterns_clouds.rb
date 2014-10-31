class CreatePatternsClouds < ActiveRecord::Migration
  def change
    create_table :patterns_clouds do |t|
      t.references :pattern
      t.references :cloud
      t.timestamps
    end
  end
end
