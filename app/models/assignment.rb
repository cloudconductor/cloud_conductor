class Assignment < ActiveRecord::Base
  belongs_to :project
  belongs_to :account

  enum role: { administrator: 0, operator: 1 }

  validates_associated :project, :account
  validates_presence_of :role
end
