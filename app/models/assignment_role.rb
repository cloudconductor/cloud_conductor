class AssignmentRole < ActiveRecord::Base
  belongs_to :assignment
  belongs_to :role

  validates_associated :assignment, :role
  validates_presence_of :assignment, :role

  def role_name
    role.name
  end

  def as_json(options = {})
    super({ methods: [:role_name] }.merge(options))
  end
end
