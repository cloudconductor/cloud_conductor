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
  end

  def default_permissions(account)
    can :manage, ActiveAdmin::Page
    can [:create, :read], Project
    can [:read, :update], Account, id: account.id
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
    # Account and Assignment
    project.assignments.each do |assign|
      can :read, Assignment, id: assign.id
    end
    project.accounts.each do |account|
      can :read, Account, id: account.id
    end

    # Project Resources
    can :read, Project, project_id: project.id
    can :manage, Cloud, project_id: project.id
    can :manage, System, project_id: project.id
    project.systems.each do |system|
      can :manage, Application, system_id: system.id
      system.applications.each do |application|
        can :manage, ApplicationHistory, application_id: application.id
      end
      can :manage, Stack, system_id: system.id
    end

    # TODO: Fix later
    # can :manage, BluePrint, project_id: project.id
    # project.blueprints.each do |blueprint|
    #   can :manage, Pattern, blueprint_id: blueprint.id
    # end
    can :manage, Pattern
  end
end
