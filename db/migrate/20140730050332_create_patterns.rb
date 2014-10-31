class CreatePatterns < ActiveRecord::Migration
  def change
    create_table :patterns do |t|
      t.string :name
      t.string :description
      t.string :type
      t.string :protocol
      t.string :url
      t.string :revision
      t.text :parameters
      t.timestamps
    end
  end
end
