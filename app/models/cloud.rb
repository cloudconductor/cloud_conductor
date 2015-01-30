class Cloud < ActiveRecord::Base
  self.inheritance_column = nil
  has_many :base_images, dependent: :destroy
  has_many :operating_systems, through: :base_images

  validates_presence_of :name, :entry_point, :key, :secret, :type
  validates_presence_of :tenant_name, if: -> { type == :openstack }
  validates :type, inclusion: { in: [:aws, :openstack, :dummy] }

  before_destroy :raise_error_in_use

  TEMPLATE_PATH = File.expand_path('../../config/templates.yml', File.dirname(__FILE__))

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
