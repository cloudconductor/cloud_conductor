class Candidate < ActiveRecord::Base
  belongs_to :cloud
  belongs_to :environment

  validates_associated :cloud, :environment
  validates_presence_of :cloud, :environment

  def self.primary
    sorted.first
  end

  scope :sorted, -> { order(priority: :desc) }
end
