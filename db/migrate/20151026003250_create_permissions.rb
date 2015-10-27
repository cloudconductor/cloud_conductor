class CreatePermissions < ActiveRecord::Migration
  def change
    create_table :permissions do |t|
      t.integer :role_id
      t.string :model
      t.string :action

      t.timestamps
    end
  end
end
