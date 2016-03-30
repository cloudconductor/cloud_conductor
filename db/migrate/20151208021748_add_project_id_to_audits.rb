class AddProjectIdToAudits < ActiveRecord::Migration
  def change
    add_column :audits, :project_id, :integer
    add_index :audits, :project_id
  end
end
