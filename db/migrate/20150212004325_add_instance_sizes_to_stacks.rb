class AddInstanceSizesToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :instance_sizes, :text
  end
end
