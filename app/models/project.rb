class Project < ActiveRecord::Base
  has_many :assignments, dependent: :destroy
  has_many :accounts, through: :assignments
  has_many :clouds, dependent: :destroy
  has_many :systems, dependent: :destroy
  has_many :blueprints, dependent: :destroy

  attr_accessor :current_account

  validates_presence_of :name
  validates_uniqueness_of :name

  def assign_project_administrator(account)
    assignments.build(account: account, role: :administrator)
  end
end
