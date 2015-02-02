class CreatePatterns < ActiveRecord::Migration
  def change
    create_table :patterns do |t|
      t.references :blueprint
      t.string :name
      t.string :type
      t.string :protocol
      t.string :url
      t.string :revision
      t.string :consul_secret_key
      t.text :parameters
      t.timestamps null: false
    end
  end
end
