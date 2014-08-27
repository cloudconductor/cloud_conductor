class CreateApplicationHistories < ActiveRecord::Migration
  def change
    create_table :application_histories do |t|
      t.references :application
      t.integer :version
      t.string :uri
      t.string :parameters
      t.timestamps
    end
  end
end
