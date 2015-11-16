class CreateRoles < ActiveRecord::Migration
  def change
    create_table :roles do |t|
      t.integer :project_id
      t.string :name
      t.string :description

      t.timestamps null: false
    end
  end
end
