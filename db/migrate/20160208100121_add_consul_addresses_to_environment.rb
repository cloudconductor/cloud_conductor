class AddConsulAddressesToEnvironment < ActiveRecord::Migration
  def change
    rename_column :environments, :ip_address, :frontend_address
    add_column :environments, :consul_addresses, :string
  end
end
