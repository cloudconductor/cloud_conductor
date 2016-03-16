class Cloud < ActiveRecord::Base
  include Encryptor
  self.inheritance_column = nil

  belongs_to :project
  has_many :stacks
  has_many :base_images, dependent: :destroy

  AWS_REGIONS = %w(us-east-1 us-west-2 us-west-1 eu-west-1 eu-central-1 ap-southeast-1 ap-southeast-2 ap-northeast-1 sa-east-1)

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates_presence_of :project, :name, :entry_point, :key, :secret, :type
  validates_presence_of :tenant_name, if: -> { type == 'openstack' }
  validates :type, inclusion: { in: %w(aws openstack wakame-vdc) }
  validates :entry_point, inclusion: { in: AWS_REGIONS }, if: -> { type == 'aws' }

  before_destroy :raise_error_in_use
  before_save :update_base_image

  def secret
    crypt.decrypt_and_verify(encrypted_secret)
  end

  def secret=(s)
    self.encrypted_secret = crypt.encrypt_and_sign(s)
  end

  def update_base_image
    base_images.destroy_all if type_changed? && persisted?
    return if type != 'aws'

    if base_images.empty?
      aws_images[entry_point].each do |image|
        base_images.build(image)
      end
    else
      aws_images[entry_point].each_with_index do |image, idx|
        base_images[idx].update_attributes(image)
      end
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
