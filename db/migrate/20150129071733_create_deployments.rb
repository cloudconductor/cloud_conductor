class CreateDeployments < ActiveRecord::Migration
  def change
    create_table :deployments do |t|
      t.references :environment
      t.references :application_history
      t.string :status
      t.timestamps null: false
    end
  end
end
