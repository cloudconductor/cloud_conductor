class CreateSystems < ActiveRecord::Migration
  def change
    create_table :systems do |t|
      t.string :name
      t.string :monitoring_host
      t.string :ip_address
      t.string :domain
      t.text :template_parameters
      t.timestamps null: false
    end
  end
end
