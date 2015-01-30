class Candidate < ActiveRecord::Base
  belongs_to :cloud
  belongs_to :system

  validates_associated :cloud, :system

  def self.primary
    sorted.first
  end

  scope :sorted, -> { order(priority: :desc) }
end
