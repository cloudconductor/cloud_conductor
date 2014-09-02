class CreateApplications < ActiveRecord::Migration
  def change
    create_table :applications do |t|
      t.references :system
      t.string :name
      t.timestamps
    end
  end
end
