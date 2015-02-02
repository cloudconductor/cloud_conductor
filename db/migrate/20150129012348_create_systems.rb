class CreateSystems < ActiveRecord::Migration
  def change
    create_table :systems do |t|
      t.references :project
      t.string :name
      t.string :description
      t.timestamps null: false
    end
  end
end
