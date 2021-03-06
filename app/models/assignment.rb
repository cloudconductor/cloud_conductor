class Assignment < ActiveRecord::Base
  belongs_to :project
  belongs_to :account

  has_many :assignment_roles, dependent: :destroy
  has_many :roles, through: :assignment_roles

  validates_associated :project, :account
  validates_presence_of :project, :account

  def email
    account.email
  end
end
