class ChangeRelationBetweenBlueprintAndPattern < ActiveRecord::Migration
  def change # rubocop:disable MethodLength
    create_table :catalogs do |t|
      t.references :blueprint, null: false
      t.references :pattern, null: false
      t.string :revision
      t.string :os_version

      t.timestamps null: false
    end

    create_table :pattern_histories do |t|
      t.references :blueprint_history, null: false
      t.references :pattern, null: false
      t.string :name
      t.string :type
      t.string :protocol
      t.string :url
      t.string :revision
      t.string :os_version
      t.text :parameters
      t.string :roles

      t.timestamps null: false
    end

    remove_column :blueprints, :consul_secret_key, :string

    remove_column :images, :pattern_id, :integer
    add_column :images, :pattern_history_id, :integer

    remove_column :patterns, :blueprint_id, :integer
    add_column :patterns, :project_id, :integer
    add_column :patterns, :roles, :string

    remove_column :stacks, :pattern_id, :integer
    add_column :stacks, :pattern_history_id, :integer

    rename_column :base_images, :os, :os_version
  end
end
