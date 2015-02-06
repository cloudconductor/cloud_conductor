class Image < ActiveRecord::Base
  belongs_to :pattern
  belongs_to :cloud
  belongs_to :base_image

  validates_associated :pattern, :cloud, :base_image
  validates_presence_of :pattern, :cloud, :base_image, :role
  validates :role, format: /\A[^\-_]+\Z/

  SPLITTER = '----'

  before_save :update_name

  after_initialize do
    self.status ||= :PROGRESS
  end

  def status
    super && super.to_sym
  end

  def update_name
    self.name = "#{base_image.name}#{SPLITTER}#{role}"
  end
end
