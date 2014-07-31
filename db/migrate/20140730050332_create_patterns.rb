class CreatePatterns < ActiveRecord::Migration
  def change
    create_table :patterns do |t|
      t.string :name
      t.string :description
      t.string :type
      t.string :uri
      t.string :revision
      t.references :metadata
      t.timestamps
    end
  end
end
