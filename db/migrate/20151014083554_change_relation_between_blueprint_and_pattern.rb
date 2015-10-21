class ChangeRelationBetweenBlueprintAndPattern < ActiveRecord::Migration
  def change
    rename_column :base_images, :os, :os_version
  end
end
