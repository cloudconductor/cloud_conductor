class AddMappingsJsonToEnvironment < ActiveRecord::Migration
  def change
    add_column :environments, :mappings_json, :text
  end
end
