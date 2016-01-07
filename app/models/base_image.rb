class BaseImage < ActiveRecord::Base
  belongs_to :cloud
  has_many :images

  validates_associated :cloud
  validates_presence_of :cloud, :platform, :source_image, :ssh_username

  after_initialize do
    self.ssh_username ||= 'ec2-user'
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
end
