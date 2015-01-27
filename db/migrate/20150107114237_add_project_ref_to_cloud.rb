class AddProjectRefToCloud < ActiveRecord::Migration
  def change
    add_reference :clouds, :project, index: true
  end
end
