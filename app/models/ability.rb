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

    assign.roles.each do |role|
      role.permissions.each do |permission|
        clazz = permission.model.classify.constantize
        can permission.action.to_sym, clazz
      end
    end
  end
end
