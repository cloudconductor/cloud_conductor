class AddProjectIdToAudits < ActiveRecord::Migration
  def change
    add_column :audits, :project_id, :string
  end
end
