class ChangeRelationBetweenBlueprintAndPattern < ActiveRecord::Migration
  def change
    remove_column :blueprints, :consul_secret_key, :string

    remove_column :patterns, :blueprint_id, :integer
    add_column :patterns, :project_id, :integer
    add_column :patterns, :roles, :string

    rename_column :base_images, :os, :os_version
  end
end
