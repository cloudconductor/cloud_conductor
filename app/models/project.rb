class Project < ActiveRecord::Base
  has_many :assignments, dependent: :destroy
  has_many :accounts, through: :assignments
  has_many :clouds, dependent: :destroy
  has_many :systems, dependent: :destroy
  has_many :applications, through: :systems
  has_many :blueprints, dependent: :destroy
  accepts_nested_attributes_for :assignments, allow_destroy: true

  attr_accessor :current_account

  validates_presence_of :name
  validates_uniqueness_of :name

  before_create :assign_project_administrator
  before_create :create_monitoring_account

  def assign_project_administrator
    assignments.build(account: current_account, role: :administrator) if current_account
  end

  def create_monitoring_account
    account = Account.create!(email: "monitoring@#{name}.example.com", name: 'monitoring', password: "#{SecureRandom.hex}")
    assignments.build(account: account, role: :operator)
  end

  def assign_project_member(account, role = :operator)
    if assignments.exists?(account: account)
      assignments.find_by(account: account).update!(role: role)
    else
      assignments.create!(account: account, role: role)
    end
  end
end
