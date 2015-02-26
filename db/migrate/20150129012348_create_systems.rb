class CreateSystems < ActiveRecord::Migration
  def change
    create_table :systems do |t|
      t.references :project
      t.references :primary_environment
      t.string :name
      t.string :description
      t.string :domain
      t.timestamps null: false
    end
  end
end
