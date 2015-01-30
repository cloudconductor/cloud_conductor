class Image < ActiveRecord::Base
  belongs_to :pattern
  belongs_to :cloud
  belongs_to :operating_system

  validates_associated :pattern, :cloud, :operating_system
  validates_presence_of :role
  validates :role, format: /\A[^\-_]+\Z/

  after_initialize do
    self.status ||= :PROGRESS
  end

  def status
    super && super.to_sym
  end
end
