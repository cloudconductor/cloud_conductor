class AddIdToCandidates < ActiveRecord::Migration
  def change
    add_column :candidates, :id, :primary_key
  end
end
