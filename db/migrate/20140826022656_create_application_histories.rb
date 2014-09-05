class CreateApplicationHistories < ActiveRecord::Migration
  def change
    create_table :application_histories do |t|
      t.references :application
      t.string :domain
      t.string :type
      t.integer :version
      t.string :protocol
      t.string :url
      t.string :revision
      t.string :pre_deploy
      t.string :post_deploy

      t.string :parameters
      t.timestamps
    end
  end
end
