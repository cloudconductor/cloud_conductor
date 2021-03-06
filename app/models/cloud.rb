class Cloud < ActiveRecord::Base
  include Encryptor
  self.inheritance_column = nil

  belongs_to :project
  has_many :stacks
  has_many :base_images, dependent: :destroy

  AWS_REGIONS = %w(us-east-1 us-west-2 us-west-1 eu-west-1 eu-central-1 ap-southeast-1 ap-southeast-2 ap-northeast-1 sa-east-1)

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates_presence_of :project, :name, :entry_point, :key, :type
  validates_presence_of :secret, if: -> { type != 'wakame-vdc' }
  validates_presence_of :tenant_name, if: -> { type == 'openstack' }
  validates :type, inclusion: { in: %w(aws openstack wakame-vdc) }
  validates :entry_point, inclusion: { in: AWS_REGIONS }, if: -> { type == 'aws' }

  before_destroy :raise_error_in_use
  before_create :create_base_image, if: -> { type == 'aws' }

  def secret
    return nil unless encrypted_secret
    crypt.decrypt_and_verify(encrypted_secret)
  end

  def secret=(s)
    self.encrypted_secret = s && crypt.encrypt_and_sign(s)
  end

  def create_base_image
    aws_images[entry_point].each do |image|
      base_images.build(image)
    end
  end

  def aws_images
    aws_images_yml = File.join(Rails.root, 'config/images.yml')
    YAML.load_file(aws_images_yml)
  end

  def client
    CloudConductor::Client.new self
  end

  def used?
    Candidate.where(cloud_id: id).count > 0 || Image.where(cloud_id: id).count > 0
  end

  def raise_error_in_use
    fail 'Can\'t destroy cloud that is used in some environments or blueprints.' if used?
  end

  def as_json(options = {})
    original_secret = secret
    self.secret = '********'
    json = super({ except: :encrypted_secret, methods: :secret }.merge(options))
    self.secret = original_secret
    json
  end
end
