class Image < ActiveRecord::Base
  belongs_to :pattern
  belongs_to :cloud
  belongs_to :operating_system

  validates :role, presence: true, format: /\A[^\-_]+\Z/

  after_initialize do
    self.status ||= :PROGRESS
  end

  def status
    super && super.to_sym
  end
end
