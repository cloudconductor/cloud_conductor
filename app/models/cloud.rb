class Cloud < ActiveRecord::Base
  TEMPLATE_PATH = File.expand_path('../../config/templates.yml', File.dirname(__FILE__))

  self.inheritance_column = nil

  has_many :base_images, dependent: :destroy
  has_many :operating_systems, through: :base_images

  before_destroy :raise_error_in_use

  validates :name, presence: true
  validates :entry_point, presence: true
  validates :key, presence: true
  validates :secret, presence: true
  validate do
    unless %i(aws openstack dummy).include? type
      errors.add(:type, ' must be "aws", "openstack" or "dummy"')
    end
    if type == :openstack
      errors.add(:tenant_name, 'must not be blank in case that type is "openstack".') if tenant_name.blank?
    end
  end

  def type
    super && super.to_sym
  end

  def client
    CloudConductor::Client.new self
  end

  def used?
    Candidate.where(cloud_id: id).count > 0
  end

  def raise_error_in_use
    fail 'Can\'t destroy cloud that is used in some systems.' if used?
  end

  def template
    templates = YAML.load_file(TEMPLATE_PATH).symbolize_keys
    templates[type].to_json
  end

  def as_json(options = {})
    original_secret = secret
    self.secret = '********'
    json = super options
    self.secret = original_secret
    json
  end
end
