class CreateAssignments < ActiveRecord::Migration
  def change
    create_table :assignments do |t|
      t.references :project, null: false
      t.references :account, null: false
      t.integer :role, default: 0

      t.timestamps null: false
    end
    add_index :assignments, [:project_id, :account_id], unique: true
  end
end
