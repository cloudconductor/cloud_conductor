class AssignmentRole < ActiveRecord::Base
  belongs_to :assignment
  belongs_to :role

  validates_associated :assignment, :role
  validates_presence_of :assignment, :role
end
