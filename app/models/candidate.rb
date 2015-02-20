class Candidate < ActiveRecord::Base
  belongs_to :cloud
  belongs_to :environment, inverse_of: :candidates

  validates_associated :cloud, :environment
  validates_presence_of :cloud, :environment

  def self.primary
    sorted.first
  end

  scope :sorted, -> { order(priority: :desc) }

  def <=>(other)
    other.priority <=> priority
  end
end
