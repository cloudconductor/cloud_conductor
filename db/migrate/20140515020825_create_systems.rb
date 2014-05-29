class CreateSystems < ActiveRecord::Migration
  def change
    create_table :systems do |t|
      t.string :name
      t.text :template_body
      t.string :template_url
      t.text :parameters
      t.string :monitoring_host
      t.string :ip_address
      t.string :domain
      t.timestamps
    end
  end
end
