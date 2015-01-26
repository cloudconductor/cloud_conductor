class AddStatusToSystems < ActiveRecord::Migration
  def change
    add_column :systems, :status, :string
  end
end
