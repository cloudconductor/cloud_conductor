class CreateTargets < ActiveRecord::Migration
  def change
    create_table :targets do |t|
      t.references :cloud
      t.references :operating_system
      t.string :source_image
      t.string :ssh_user_name
    end
  end
end
