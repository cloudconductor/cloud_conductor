class CreateStacks < ActiveRecord::Migration
  def change
    create_table :stacks do |t|
      t.references :system
      t.references :pattern
      t.references :cloud
      t.string :name
      t.string :status
      t.text :template_parameters
      t.text :parameters
      t.timestamps null: false
    end
  end
end
