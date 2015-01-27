class AddProjectRefToSystem < ActiveRecord::Migration
  def change
    add_reference :systems, :project, index: true
  end
end
