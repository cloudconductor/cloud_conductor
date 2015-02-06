class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.references :pattern
      t.references :cloud
      t.references :base_image
      t.string :name
      t.string :role
      t.string :image
      t.string :message
      t.string :status
      t.timestamps null: false
    end
  end
end
