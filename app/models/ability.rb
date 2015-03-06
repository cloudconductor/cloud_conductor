class Ability
  include CanCan::Ability

  def initialize(account)
    account ||= Account.new
    if account.admin?
      administrator_permissions
    else
      # administrator_permissions
      default_permissions(account)
      account.assignments.each do |assign|
        if assign.administrator?
          project_admin_permissions(assign.project)
        elsif assign.operator?
          project_operator_permissions(assign.project)
        end
      end
    end
  end

  private

  def administrator_permissions
    can :manage, :all
    can :update_admin, Account
  end

  def default_permissions(account)
    can :manage, ActiveAdmin::Page
    can [:create], Project
    can [:read, :update], Account, id: account.id
    cannot :update_admin, Account
  end

  def project_admin_permissions(project)
    project_operator_permissions(project)
    can :manage, Project, id: project.id
    can :create, Assignment, project_id: project.id
    can :create, Account
    project.assignments.each do |assign|
      can :manage, Assignment, id: assign.id
    end
  end

  def project_operator_permissions(project)
    allow_read_project(project)
    allow_manage_project_resources(project)
  end

  def allow_read_project(project)
    can :read, Project, id: project.id
    project.assignments.each do |assign|
      can :read, Assignment, id: assign.id
    end
    project.accounts.each do |account|
      can :read, Account, id: account.id
    end
  end

  def allow_manage_project_resources(project)
    # Cloud and dependent resources
    can :manage, Cloud, project_id: project.id
    project.clouds.each do |cloud|
      can :manage, BaseImage, cloud_id: cloud.id
    end
    # Blueprint and denepdent resources
    can :manage, Blueprint, project_id: project.id
    project.blueprints.each do |blueprint|
      can :manage, Pattern, blueprint_id: blueprint.id
    end
    # System and dependent resources
    can :manage, System, project_id: project.id
    project.systems.each do |system|
      can :manage, Environment, system_id: system.id
      system.environments.each do |environment|
        can :manage, Deployment, environment_id: environment.id
      end
      can :manage, Application, system_id: system.id
      system.applications.each do |application|
        can :manage, ApplicationHistory, application_id: application.id
      end
      can :manage, Stack, system_id: system.id
    end
  end
end
