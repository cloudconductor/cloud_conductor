class Pattern < ActiveRecord::Base
  include PatternAccessor
  include Encryptor
  self.inheritance_column = nil

  belongs_to :project
  has_many :blueprint_patterns, dependent: :destroy
  has_many :blueprints, through: :blueprint_patterns

  validates_presence_of :project
  validates :url, format: { with: URI.regexp }

  after_initialize do
    self.protocol ||= 'git'
  end

  before_save :update_metadata

  def secret_key
    encrypted_secret_key = read_attribute(:secret_key)
    return encrypted_secret_key if encrypted_secret_key.blank?
    crypt.decrypt_and_verify(encrypted_secret_key)
  end

  def secret_key=(s)
    write_attribute(:secret_key, s) if s.blank?
    write_attribute(:secret_key, crypt.encrypt_and_sign(s))
  end

  def as_json(options = {})
    original_secret_key = secret_key
    self.secret_key = '********'
    json = super({ except: :parameters, methods: :secret_key }.merge(options))
    self.secret_key = original_secret_key
    json
  end

  private

  def update_metadata
    options = { secret_key: secret_key }
    clone_repository(url, revision, options) do |path|
      metadata = load_metadata(path)

      self.name = metadata[:name]
      self.type = metadata[:type]
      self.providers = metadata[:providers].to_json
      self.parameters = read_parameters(path).to_json
      self.roles = (metadata[:roles] || []).to_json
    end
  end
end
