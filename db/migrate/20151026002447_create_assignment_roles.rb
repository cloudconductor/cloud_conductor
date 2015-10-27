class CreateAssignmentRoles < ActiveRecord::Migration
  def change
    create_table :assignment_roles do |t|
      t.integer :assignment_id
      t.integer :role_id

      t.timestamps
    end
  end
end
