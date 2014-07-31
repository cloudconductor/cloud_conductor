class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.references :pattern
      t.references :cloud
      t.string :role
      t.string :name
      t.string :status
      t.timestamps
    end
  end
end
