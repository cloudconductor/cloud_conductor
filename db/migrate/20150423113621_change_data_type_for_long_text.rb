class ChangeDataTypeForLongText < ActiveRecord::Migration
  def change
    change_column :images, :message, :text
    change_column :application_histories, :parameters, :text

    change_column :applications, :description, :text
    change_column :blueprints, :description, :text
    change_column :clouds, :description, :text
    change_column :environments, :description, :text
    change_column :projects, :description, :text
    change_column :systems, :description, :text
  end
end
