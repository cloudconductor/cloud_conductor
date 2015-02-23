class CreateEnvironments < ActiveRecord::Migration
  def change
    create_table :environments do |t|
      t.references :system
      t.references :blueprint
      t.string :name
      t.string :description
      t.string :status
      t.string :ip_address
      t.text :template_parameters
      t.timestamps null: false
    end
  end
end
