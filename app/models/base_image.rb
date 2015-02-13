class BaseImage < ActiveRecord::Base
  belongs_to :cloud
  has_many :images

  validates_associated :cloud
  validates_presence_of :cloud, :os, :source_image, :ssh_username

  cattr_accessor :ami_images

  SPLITTER = '----'
  DEFAULT_OS = 'CentOS-6.5'
  DEFAULT_SSH_USERNAME = 'ec2-user'
  ALLOW_RECEIVERS = %w(base_image cloud os)
  IMAGES_FILE_PATH = File.expand_path('../../config/images.yml', File.dirname(__FILE__))

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

  def to_json
    template = cloud.template
    template.gsub(/\{\{(\w+)\s*`(\w+)`\}\}/) do
      receiver_name = Regexp.last_match[1]
      method_name = Regexp.last_match[2]
      next Regexp.last_match[0] unless ALLOW_RECEIVERS.include? receiver_name
      send(receiver_name).send(method_name)
    end
  end

  def base_image
    self
  end
end
