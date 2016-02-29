module Encryptor
  def crypt
    secure = Rails.application.key_generator.generate_key('encrypted secret')
    sign_secure = Rails.application.key_generator.generate_key('signed encrypted secret')
    ActiveSupport::MessageEncryptor.new(secure, sign_secure)
  end
end
