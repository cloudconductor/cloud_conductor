class Image < ActiveRecord::Base
  belongs_to :pattern_snapshot
  belongs_to :cloud
  belongs_to :base_image

  validates_associated :pattern_snapshot, :cloud, :base_image
  validates_presence_of :pattern_snapshot, :cloud, :base_image, :role

  before_save :update_name
  before_destroy :destroy_image, if: -> { status == :CREATE_COMPLETE }

  after_initialize do
    self.status ||= :PROGRESS
  end

  def status
    super && super.to_sym
  end

  def update_name
    splitter = '----'
    self.name = "#{base_image.name}#{splitter}#{role.gsub(/\s*,\s*/, '-')}"
  end

  def destroy_image
    cloud.client.destroy_image image
  end
end
