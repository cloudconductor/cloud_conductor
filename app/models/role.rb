class Role < ActiveRecord::Base
  belongs_to :project
  has_many :assignment_roles, dependent: :destroy
  has_many :assignments, through: :assignment_roles

  validates_presence_of :name, :project

  validates :name, uniqueness: { scope: :project_id }
end
