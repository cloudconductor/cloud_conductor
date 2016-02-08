class AddConsulAddressesToEnvironment < ActiveRecord::Migration
  def change
    add_column :environments, :consul_addresses, :string
  end
end
