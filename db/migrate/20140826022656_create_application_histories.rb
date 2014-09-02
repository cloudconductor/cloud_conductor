class CreateApplicationHistories < ActiveRecord::Migration
  def change
    create_table :application_histories do |t|
      t.references :application
      t.integer :version
      t.string :url
      t.string :revision
      t.string :parameters
      t.timestamps
    end
  end
end
