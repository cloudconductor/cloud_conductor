class AssignmentRole < ActiveRecord::Base
  belongs_to :assignment
  belongs_to :role

  validates_associated :assignment, :role
  validates_presence_of :assignment, :role

  validate :valid_same_project

  def valid_same_project
    errors.add(:valid_same_project, 'Project mismatch!') unless assignment.project == role.project
  end

  def role_name
    role.name
  end

  def as_json(options = {})
    super({ methods: [:role_name] }.merge(options))
  end
end
