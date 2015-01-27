class Project < ActiveRecord::Base
  has_many :assignments, dependent: :destroy
  has_many :accounts, through: :assignments
  has_many :clouds, dependent: :destroy
  has_many :systems, dependent: :destroy
  # has_many :blueprints, dependent: :destroy

  attr_accessor :current_account
  # before_create :assign_project_administrator

  validates :name, presence: true, uniqueness: true

  def assign_project_administrator(account)
    assignments.build(account: account, role: :administrator)
  end
end
