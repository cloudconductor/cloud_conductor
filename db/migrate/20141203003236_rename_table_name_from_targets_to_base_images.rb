class RenameTableNameFromTargetsToBaseImages < ActiveRecord::Migration
  def change
    rename_table :targets, :base_images
  end
end
