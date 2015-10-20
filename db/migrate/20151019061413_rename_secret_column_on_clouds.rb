class RenameSecretColumnOnClouds < ActiveRecord::Migration
  class TransferCloud < ActiveRecord::Base
    self.table_name = :clouds
    self.inheritance_column = nil
  end

  def up
    cipher = 'aes-256-cbc'
    secure = CloudConductor::Config.secure.key

    rename_column :clouds, :secret, :encrypted_secret
    TransferCloud.all.each do |cloud|
      begin
        crypt = ActiveSupport::MessageEncryptor.new(secure, cipher)
        value = crypt.encrypt_and_sign(cloud.encrypted_secret)
        cloud.update_attributes!(encrypted_secret: value)
      rescue
        next
      end
    end
  end

  def down
    cipher = 'aes-256-cbc'
    secure = CloudConductor::Config.secure.key

    rename_column :clouds, :encrypted_secret, :secret
    TransferCloud.all.each do |cloud|
      begin
        crypt = ActiveSupport::MessageEncryptor.new(secure, cipher)
        value = crypt.decrypt_and_verify(cloud.secret)
        cloud.update_attributes!(secret: value)
      rescue
        next
      end
    end
  end
end
