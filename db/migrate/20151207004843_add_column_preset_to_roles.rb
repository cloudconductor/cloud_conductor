class AddColumnPresetToRoles < ActiveRecord::Migration
  def up
    add_column :roles, :preset, :boolean, default: false, null: false
  end

  def down
    remove_column :roles, :preset, :boolean
  end
end
