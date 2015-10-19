class RenameSecretColumnOnClouds < ActiveRecord::Migration
  def change
    rename_column :clouds, :secret, :encrypted_secret
  end
end
