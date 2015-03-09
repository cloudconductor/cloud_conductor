class Cloud < ActiveRecord::Base
  self.inheritance_column = nil

  belongs_to :project
  has_many :stacks
  has_many :base_images, dependent: :destroy

  AWS_REGIONS = %w(us-east-1 us-west-2 us-west-1 eu-west-1 eu-central-1 ap-southeast-1 ap-southeast-2 ap-northeast-1 sa-east-1)

  validates_presence_of :project, :name, :entry_point, :key, :secret, :type
  validates_presence_of :tenant_name, if: -> { type == 'openstack' }
  validates :type, inclusion: { in: %w(aws openstack) }
  validates :entry_point, inclusion: { in: AWS_REGIONS }, if: -> { type == 'aws' }

  before_destroy :raise_error_in_use
  after_save :set_base_image, if: -> { type == 'aws' }

  def set_base_image
    return unless type == 'aws'
    if base_images.empty?
      base_images.create!(source_image: aws_images[entry_point])
    else
      base_images.first.update_attributes!(source_image: aws_images[entry_point])
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
    Candidate.where(cloud_id: id).count > 0
  end

  def raise_error_in_use
    fail 'Can\'t destroy cloud that is used in some systems.' if used?
  end

  def as_json(options = {})
    original_secret = secret
    self.secret = '********'
    json = super options
    self.secret = original_secret
    json
  end
end
