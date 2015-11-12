class RenameSecretColumnOnClouds < ActiveRecord::Migration
  class TransferCloud < ActiveRecord::Base
    self.table_name = :clouds
    self.inheritance_column = nil
  end

  def up
    secret = Rails.application.key_generator.generate_key('encrypted secret')
    sign_secret = Rails.application.key_generator.generate_key('signed encrypted secret')

    rename_column :clouds, :secret, :encrypted_secret
    TransferCloud.all.each do |cloud|
      begin
        crypt = ActiveSupport::MessageEncryptor.new(secret, sign_secret)
        value = crypt.encrypt_and_sign(cloud.encrypted_secret)
        cloud.update_attributes!(encrypted_secret: value)
      rescue
        next
      end
    end
  end

  def down
    secret = Rails.application.key_generator.generate_key('encrypted secret')
    sign_secret = Rails.application.key_generator.generate_key('signed encrypted secret')

    rename_column :clouds, :encrypted_secret, :secret
    TransferCloud.all.each do |cloud|
      begin
        crypt = ActiveSupport::MessageEncryptor.new(secret, sign_secret)
        value = crypt.decrypt_and_verify(cloud.secret)
        cloud.update_attributes!(secret: value)
      rescue
        next
      end
    end
  end
end
