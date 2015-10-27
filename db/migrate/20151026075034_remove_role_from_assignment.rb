class RemoveRoleFromAssignment < ActiveRecord::Migration
  class TransferAssignment < ActiveRecord::Base
    self.table_name = :assignments

    belongs_to :project
    belongs_to :account

    has_many :assignment_roles, dependent: :destroy, foreign_key: :assignment_id
    has_many :roles, through: :assignment_roles
    accepts_nested_attributes_for :assignment_roles, allow_destroy: true

    def add_role(role)
      roles << role
    end
  end

  def create_role_admin(project)
    project.roles.build(name: 'administrator') unless project.roles.find_by(name: 'administrator')
    project.roles.find_by(name: 'administrator')
  end

  def create_role_operator(project)
    project.roles.build(name: 'operator') unless project.roles.find_by(name: 'operator')
    project.roles.find_by(name: 'operator')
  end

  def up
    TransferAssignment.all.each do |assignment|
      project = assignment.project

      if assignment.role == 1
        role = create_role_admin(project)
        assignment.add_role role
      else
        role = create_role_operator(project)
        assignment.add_role role
      end
      assignment.save!
    end

    remove_column :assignments, :role, :integer
  end

  def down
    add_column :assignments, :role, :integer, default: 0

    TransferAssignment.all.each do |assignment|
      role = assignment.roles.find_by(name: 'administrator')
      if role
        assignment.role = 1
        #      else
        #        assignment.role = 0
      end
      assignment.save!
    end
  end
end
