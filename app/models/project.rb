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

  before_create :create_preset_roles
  before_create :assign_project_administrator
  before_create :create_monitoring_account

  before_update :update_monitoring_account
  before_destroy :delete_monitoring_account

  def assign_project_administrator
    role = roles.find { |role| role.name == 'administrator' } || roles.build(name: 'administrator', preset: true)

    assignments.build(account: current_account, roles: [role]) if current_account
  end

  def create_monitoring_account
    role = roles.find { |role| role.name == 'operator' } || roles.build(name: 'operator', preset: true)

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

    # role_admin = roles.find { |role| role.name == 'administrator' } || roles.build(name: 'administrator')

    permissions_attributes = []

    permissions_attributes << { model: 'project', action: 'manage' }
    permissions_attributes << { model: 'assignment', action: 'manage' }
    permissions_attributes << { model: 'account', action: 'read' }
    permissions_attributes << { model: 'account', action: 'create' }
    permissions_attributes << { model: 'role', action: 'manage' }
    permissions_attributes << { model: 'permission', action: 'manage' }
    models.each do |model|
      permissions_attributes << { model: model.to_s, action: 'manage' }
    end

    roles.build(name: 'administrator', permissions_attributes: permissions_attributes, preset: true)
  end

  def create_operator_role
    models = [:cloud, :base_image, :pattern, :blueprint, :blueprint_pattern, :blueprint_history]
    models += [:system, :environment, :application, :application_history, :deployment]

    # role_operator = roles.find { |role| role.name == 'operator' } || roles.build(name: 'operator')

    permissions_attributes = []
    permissions_attributes << { model: 'project', action: 'read' }
    permissions_attributes << { model: 'assignment', action: 'read' }
    permissions_attributes << { model: 'account', action: 'read' }
    permissions_attributes << { model: 'role', action: 'read' }
    permissions_attributes << { model: 'permission', action: 'read' }
    models.each do |model|
      permissions_attributes << { model: model.to_s, action: 'manage' }
    end

    roles.build(name: 'operator', permissions_attributes: permissions_attributes, preset: true)
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

  def base_images(platform)
    clouds.map do |cloud|
      BaseImage.find_by(platform: platform, cloud: cloud)
    end.compact
  end
end
