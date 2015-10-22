class Ability
  include CanCan::Ability

  def initialize(account, project = nil)
    account ||= Account.new
    if account.admin?
      administrator_permissions
    else
      user_role_permissions(account, project)
    end
  end

  private

  def administrator_permissions
    can :manage, :all
    can :update_admin, Account
  end

  def user_role_permissions(account, project)
    cannot :update_admin, Account
    cannot :manage, :all

    can [:read, :update], Account, id: account.id
    can [:create], Project

    assign = account.assignments.find_by(project: project)
    return unless assign

    if assign.administrator?
      project_admin_permissions
    else
      project_operator_permissions
    end
  end

  def project_admin_permissions
    can :manage, Project
    can :manage, Assignment
    can [:read, :create], Account
    can :manage, Cloud
    can :manage, BaseImage
    can :manage, Blueprint
    can :manage, BlueprintPattern
    can :manage, BlueprintHistory
    can :manage, Pattern
    can :manage, System
    can :manage, Environment
    can :manage, Deployment
    can :manage, Application
    can :manage, ApplicationHistory
    can :manage, Stack
  end

  def project_operator_permissions
    can :read, Project
    can :read, Assignment
    can :read, Account
    can :manage, Cloud
    can :manage, BaseImage
    can :manage, Blueprint
    can :manage, BlueprintPattern
    can :manage, BlueprintHistory
    can :manage, Pattern
    can :manage, System
    can :manage, Environment
    can :manage, Deployment
    can :manage, Application
    can :manage, ApplicationHistory
    can :manage, Stack
  end
end
