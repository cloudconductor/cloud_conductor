class CreateApplications < ActiveRecord::Migration
  def change
    create_table :applications do |t|
      t.references :system
      t.string :name
      t.string :description
      t.timestamps null: false
    end
  end
end
