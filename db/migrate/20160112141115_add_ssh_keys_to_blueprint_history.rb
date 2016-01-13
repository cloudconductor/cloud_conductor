class AddSshKeysToBlueprintHistory < ActiveRecord::Migration
  def change
    add_column :blueprint_histories, :encrypted_ssh_private_key, :text
  end
end
