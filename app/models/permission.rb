class Permission < ActiveRecord::Base
  belongs_to :role

  validates_associated :role
  validates_presence_of :role, :model, :action

  validates :action, uniqueness: { scope: [:role_id, :model] }
end
