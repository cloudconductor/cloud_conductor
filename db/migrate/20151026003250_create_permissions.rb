class CreatePermissions < ActiveRecord::Migration
  def change
    create_table :permissions do |t|
      t.integer :role_id
      t.string :model
      t.string :action

      t.timestamps null: false
    end
    add_index :permissions, [:role_id, :model, :action], unique: true
  end
end
