class Role < ActiveRecord::Base
  belongs_to :project
  has_many :assignment_roles, dependent: :destroy
  has_many :assignments, through: :assignment_roles
  has_many :permissions, dependent: :destroy

  validates_presence_of :name, :project

  validates :name, uniqueness: { scope: :project_id }

  before_destroy :raise_error_in_use

  def used?
    assignments.count > 0
  end

  def raise_error_in_use
    fail 'Can\'t destroy role that is used in some account assignments.' if used?
  end
end
