class Assignment < ActiveRecord::Base
  belongs_to :project
  belongs_to :account

  has_many :assignment_roles, dependent: :destroy
  has_many :roles, through: :assignment_roles

  validates_associated :project, :account
  validates_presence_of :project, :account

  scope :find_by_project_id, -> (project_id) { where(project_id: project_id) }
  scope :find_by_account_id, -> (account_id) { where(account_id: account_id) }
  scope :search, lambda { |project_id, account_id|
    where(arel_table[:project_id].eq(project_id)
          .and(arel_table[:account_id].eq(account_id)))
  }

  def email
    account.email
  end

  def administrator?
    roles.all.count do |role|
      role.name == 'administrator'
    end > 0
  end
end
