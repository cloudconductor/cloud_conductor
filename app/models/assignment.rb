class Assignment < ActiveRecord::Base
  belongs_to :project
  belongs_to :account

  enum role: { operator: 0, administrator: 1 }

  validates_associated :project, :account
  validates_presence_of :project, :account, :role

  attr_accessor :email
end
