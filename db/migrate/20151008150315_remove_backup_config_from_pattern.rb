class RemoveBackupConfigFromPattern < ActiveRecord::Migration
  def change
    remove_column :patterns, :backup_config, :text
  end
end
