class BaseImage < ActiveRecord::Base
  belongs_to :cloud
  has_many :images

  validates_associated :cloud
  validates_presence_of :cloud, :os, :source_image, :ssh_username

  after_initialize do
    self.ssh_username ||= 'ec2-user'
    self.os ||= 'CentOS-6.5'
  end

  def name
    "#{cloud.name}-#{os}"
  end

  def builder
    packer_builder_template_erb = File.read(File.join(Rails.root, 'config/templates.yml.erb'))
    packer_builder_template = YAML.load(ERB.new(packer_builder_template_erb).result(binding))
    packer_builder_template[cloud.type].with_indifferent_access
  end
end
