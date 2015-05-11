class MoveDomainColumnFromApplicationHistoryToApplication < ActiveRecord::Migration
  def change
    add_column :applications, :domain, :string
    remove_column :application_histories, :domain
  end
end
