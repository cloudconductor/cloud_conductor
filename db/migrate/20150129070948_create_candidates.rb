class CreateCandidates < ActiveRecord::Migration
  def change
    create_table :candidates do |t|
      t.references :cloud
      t.references :environment
      t.integer :priority
      t.timestamps null: false
    end
  end
end
