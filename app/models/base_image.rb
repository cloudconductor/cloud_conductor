class BaseImage < ActiveRecord::Base
  belongs_to :cloud
  has_many :images

  validates_associated :cloud
  validates_presence_of :cloud, :os, :source_image, :ssh_username

  cattr_accessor :ami_images

  SPLITTER = '----'
  DEFAULT_OS = 'CentOS-6.5'
  DEFAULT_SSH_USERNAME = 'ec2-user'
  IMAGES_FILE_PATH = File.expand_path('../../config/images.yml', File.dirname(__FILE__))
  TEMPLATE_PATH = File.expand_path('../../config/templates.yml.erb', File.dirname(__FILE__))

  after_initialize do
    self.ssh_username ||= DEFAULT_SSH_USERNAME
    self.os ||= DEFAULT_OS

    BaseImage.ami_images ||= YAML.load_file(IMAGES_FILE_PATH)
    if cloud && cloud.type == :aws && source_image.nil?
      self.source_image = BaseImage.ami_images[cloud.entry_point]
    end
  end

  def name
    "#{cloud.name}#{SPLITTER}#{os}"
  end

  def builder
    templates = YAML.load(ERB.new(IO.read(TEMPLATE_PATH)).result(binding))
    templates[cloud.type.to_s].with_indifferent_access
  end
end
