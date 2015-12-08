class CreateAssignmentRoles < ActiveRecord::Migration
  def change
    create_table :assignment_roles do |t|
      t.integer :assignment_id
      t.integer :role_id

      t.timestamps null: false
    end
    add_index :assignment_roles, [:assignment_id, :role_id], unique: true
  end
end
