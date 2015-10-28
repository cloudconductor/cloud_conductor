class Project < ActiveRecord::Base
  has_many :assignments, dependent: :destroy
  has_many :accounts, through: :assignments
  has_many :clouds, dependent: :destroy
  has_many :systems, dependent: :destroy
  has_many :applications, through: :systems
  has_many :blueprints, dependent: :destroy
  has_many :roles, dependent: :destroy
  accepts_nested_attributes_for :assignments, allow_destroy: true

  attr_accessor :current_account

  validates_presence_of :name
  validates_uniqueness_of :name

  before_create :assign_project_administrator
  before_create :create_monitoring_account
  before_create :create_preset_roles

  before_update :update_monitoring_account
  before_destroy :delete_monitoring_account

  def assign_project_administrator
    role = roles.find_by(name: 'administrator') || roles.build(name: 'administrator')
    assignments.build(account: current_account, roles: [role]) if current_account
  end

  def create_monitoring_account
    role = roles.find_by(name: 'operator') || roles.build(name: 'operator')
    account = Account.create!(email: "monitoring@#{name}.example.com", name: 'monitoring', password: "#{SecureRandom.hex}")
    assignments.build(account: account, roles: [role])
  end

  def create_preset_roles
    create_admin_role
    create_operator_role
  end

  def create_admin_role
    models = [:cloud, :base_image, :pattern, :blueprint, :blueprint_pattern, :blueprint_history]
    models += [:system, :environment, :application, :application_history, :deployment]

    role_admin = roles.select do |role|
      role.name == 'administrator'
    end.first
    role_admin ||= roles.build(name: 'administrator')

    role_admin.add_permission(:project, :manage)
    role_admin.add_permission(:assignment, :manage)
    role_admin.add_permission(:account, :read, :create)
    role_admin.add_permission(:role, :manage)
    role_admin.add_permission(:permission, :manage)
    models.each do |model|
      role_admin.add_permission(model, :manage)
    end
  end

  def create_operator_role
    models = [:cloud, :base_image, :pattern, :blueprint, :blueprint_pattern, :blueprint_history]
    models += [:system, :environment, :application, :application_history, :deployment]

    role_operator = roles.select do |role|
      role.name == 'operator'
    end.first
    role_operator ||= roles.build(name: 'operator')

    role_operator.add_permission(:project, :read)
    role_operator.add_permission(:assignment, :read)
    role_operator.add_permission(:account, :read, :read)
    role_operator.add_permission(:role, :read)
    role_operator.add_permission(:permission, :read)
    models.each do |model|
      role_operator.add_permission(model, :manage)
    end
  end

  def update_monitoring_account
    account = assignments.map(&:account).find { |account| account.email =~ /monitoring@.*\.example\.com/ }
    account.update_attributes!(email: "monitoring@#{name}.example.com")
  end

  def delete_monitoring_account
    Account.where(email: "monitoring@#{name}.example.com").destroy_all
  end

  def assign_project_member(account, role = :operator)
    r = roles.find_by(name: role)
    if assignments.exists?(account: account)
      assignments.find_by(account: account).update!(roles: [r])
    else
      assignments.create!(account: account, roles: [r])
    end
  end

  def base_images(os_version)
    clouds.map do |cloud|
      BaseImage.find_by(os_version: os_version, cloud: cloud)
    end.compact
  end
end
