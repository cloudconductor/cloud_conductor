class ChangeRelationBetweenBlueprintAndPattern < ActiveRecord::Migration
  def change
    create_table :catalogs do |t|
      t.references :blueprint, null: false
      t.references :pattern, null: false
      t.string :revision
      t.string :os_version

      t.timestamps null: false
    end

    remove_column :blueprints, :consul_secret_key, :string

    remove_column :patterns, :blueprint_id, :integer
    add_column :patterns, :project_id, :integer
    add_column :patterns, :roles, :string

    rename_column :base_images, :os, :os_version
  end
end
