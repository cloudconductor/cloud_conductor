class CreatePatterns < ActiveRecord::Migration
  def change
    create_table :patterns do |t|
      t.references :blueprint
      t.string :name
      t.string :type
      t.string :protocol
      t.string :url
      t.string :revision
      t.text :parameters
      t.text :backup_config
      t.timestamps null: false
    end
  end
end
