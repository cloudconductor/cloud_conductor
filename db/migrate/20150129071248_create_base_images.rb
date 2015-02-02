class CreateBaseImages < ActiveRecord::Migration
  def change
    create_table :base_images do |t|
      t.references :cloud
      t.string :operating_system
      t.string :source_image
      t.string :ssh_username
      t.timestamps null: false
    end
  end
end
