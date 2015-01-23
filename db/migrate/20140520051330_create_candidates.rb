class CreateCandidates < ActiveRecord::Migration
  def change
    create_table :candidates, id: false do |t|
      t.references :cloud
      t.references :system
      t.integer :priority
      t.boolean :active
      t.timestamps null: false
    end
  end
end
