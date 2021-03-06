class BaseImage < ActiveRecord::Base
  belongs_to :cloud
  has_many :images

  validates_associated :cloud
  validates_presence_of :cloud, :platform, :source_image, :ssh_username
  validates :platform, uniqueness: { scope: [:cloud, :platform_version] }
  validate do
    errors.add(:platform, 'is invalid') if platform && !Platform.family(platform)
  end

  after_initialize do
    self.ssh_username ||= 'centos'
  end

  scope :select_by_project_id, -> (project_id) { joins(:cloud).where(clouds: { project_id: project_id }) }

  def project
    cloud.project
  end

  def name
    "#{cloud.name}-#{platform}-#{platform_version}"
  end

  def builder
    template_path = File.join(Rails.root, "config/template_#{cloud.type}.yml.erb")
    YAML.load(ERB.new(File.read(template_path)).result(binding)).with_indifferent_access
  end

  def self.filtered_base_image(cloud, platform, platform_version)
    base_images = BaseImage.where(cloud: cloud)
    result = base_images.find do |base_image|
      base_image.platform.downcase == platform.downcase &&
      base_image.platform_version.try!(:downcase) == platform_version.try!(:downcase)
    end
    return result if result

    result = base_images.find { |base_image| base_image.platform.downcase == platform.downcase }
    return result if result

    base_images.find { |base_image| Platform.family(base_image.platform) == Platform.family(platform) }
  end
end
