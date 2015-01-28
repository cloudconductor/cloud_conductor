class AddEventToApplicationHistories < ActiveRecord::Migration
  def change
    add_column :application_histories, :event, :string
  end
end
