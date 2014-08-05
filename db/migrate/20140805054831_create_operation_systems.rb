class CreateOperationSystems < ActiveRecord::Migration
  def change
    create_table :operation_systems do |t|
      t.string :name
    end
  end
end
