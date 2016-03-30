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
    can [:read], Account

    assign = account.assignments.find_by(project: project)
    return unless assign

    Permission.joins(role: [:assignments])
      .where(assignments: { project_id: project.id, account_id: account.id }).each do |permission|
      klass = permission.model.classify.constantize
      next if klass == Account

      can permission.action.to_sym, klass
    end

    cannot [:update, :destroy], Role, preset: true
  end
end
