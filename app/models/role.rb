class Role < ActiveRecord::Base
  belongs_to :project
  has_many :assignment_roles, dependent: :destroy
  has_many :assignments, through: :assignment_roles
  has_many :permissions, dependent: :destroy

  accepts_nested_attributes_for :permissions

  validates_presence_of :name, :project

  validates :name, uniqueness: { scope: :project_id }

  before_destroy :raise_error_in_use

  scope :granted_to, lambda { |project_id, account_id|
    joins(:assignments)
      .where(project_id: project_id, assignments: { account_id: account_id })
  }

  def used?
    assignments.count > 0
  end

  def raise_error_in_use
    fail 'Can\'t destroy role that is used in some account assignments.' if used?
  end

  def add_permission(model, *actions)
    actions.each do |action|
      permissions.create(model: model.to_s, action: action.to_s)
    end
  end
end
