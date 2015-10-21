class ChangeRelationBetweenBlueprintAndPattern < ActiveRecord::Migration
  def change
    remove_column :blueprints, :consul_secret_key, :string

    rename_column :base_images, :os, :os_version
  end
end
