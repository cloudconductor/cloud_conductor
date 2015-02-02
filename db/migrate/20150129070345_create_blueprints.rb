class CreateBlueprints < ActiveRecord::Migration
  def change
    create_table :blueprints do |t|
      t.references :project
      t.string :name
      t.string :description
      t.integer :version
      t.timestamps null: false
    end
  end
end
