require 'open-uri'

class Environment < ActiveRecord::Base # rubocop:disable ClassLength
  belongs_to :system
  belongs_to :blueprint_history
  has_many :candidates, dependent: :destroy, inverse_of: :environment
  has_many :clouds, through: :candidates
  has_many :stacks, validate: false
  has_many :deployments, -> { includes :application_history }, dependent: :destroy, inverse_of: :environment
  has_many :application_histories, through: :deployments
  accepts_nested_attributes_for :candidates

  attr_accessor :user_attributes

  validates_presence_of :system, :blueprint_history, :candidates
  validates :name, presence: true, uniqueness: true
  validate do
    clouds = candidates.map(&:cloud)
    errors.add(:clouds, 'can\'t contain duplicate cloud in clouds attribute') unless clouds.size == clouds.uniq.size
  end
  validate do
    if blueprint_history
      errors.add(:blueprint_history, 'status does not create_complete') unless blueprint_history.status == :CREATE_COMPLETE
    end
  end

  before_save :create_or_update_stacks, if: -> { status == :PENDING }
  before_destroy :destroy_stacks_in_background

  after_initialize do
    self.template_parameters ||= '{}'
    self.user_attributes ||= '{}'
    self.platform_outputs ||= '{}'
    self.status ||= :PENDING
  end

  scope :select_by_project_id, -> (project_id) { joins(:system).where(systems: { project_id: project_id }) }

  def project
    system.project
  end

  def create_or_update_stacks
    if (new_record? || blueprint_history_id_changed?) && stacks.empty?
      create_stacks
    elsif template_parameters != '{}' || user_attributes != '{}'
      update_stacks
    end
  end

  def create_stacks
    primary_cloud = candidates.sort.first.cloud
    user_attributes_hash = JSON.parse(user_attributes)
    blueprint_history.pattern_snapshots.each do |pattern_snapshot|
      pattern_name = pattern_snapshot.name
      stacks.build(
        cloud: primary_cloud,
        pattern_snapshot: pattern_snapshot,
        name: "#{system.name}-#{id}-#{pattern_name}",
        template_parameters: cfn_parameters(pattern_name).to_json,
        parameters: (user_attributes_hash[pattern_name] || {}).to_json
      )
    end
  end

  def update_stacks
    user_attributes_hash = JSON.parse(user_attributes)
    stacks.each do |stack|
      pattern_name = stack.pattern_snapshot.name
      new_template_parameters = cfn_parameters(pattern_name).to_json
      new_user_attributes = (user_attributes_hash[pattern_name] || {}).to_json
      stack.update!(template_parameters: new_template_parameters, parameters: new_user_attributes, status: :PENDING)
    end
  end

  def build_infrastructure
    result = candidates.sorted.map(&:cloud).any? do |cloud|
      begin
        builder = CloudConductor::Builders.builder(cloud, self)
        builder.build
      rescue => e
        Log.error e.message
        false
      end
    end
    unless result
      update_attribute(:status, :ERROR)
      fail 'Failed to create environment over all candidates' unless result
    end
  end

  def update_infrastructure
    cloud = stacks.first.cloud
    updater = CloudConductor::Updaters.updater(cloud, self)
    updater.update
  rescue => e
    Log.error e.message
    update_attribute(:status, :ERROR)
    raise 'Failed to update environment over all candidates'
  end

  def status
    super && super.to_sym
  end

  def application_status
    if latest_deployments.empty?
      :NOT_DEPLOYED
    elsif latest_deployments.any? { |deployment| deployment.status == 'ERROR' }
      :ERROR
    elsif latest_deployments.any? { |deployment| deployment.status == 'PROGRESS' }
      :PROGRESS
    elsif latest_deployments.all? { |deployment| deployment.status == 'DEPLOY_COMPLETE' }
      :DEPLOY_COMPLETE
    else
      :ERROR
    end
  end

  def basename
    name.sub(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, '')
  end

  def as_json(options = {})
    super({ methods: [:status, :application_status], except: :platform_outputs }.merge(options))
  end

  def dup
    environment = super

    basename = name.sub(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, '')
    environment.name = "#{basename}-#{SecureRandom.uuid}"
    environment.frontend_address = nil
    environment.consul_addresses = nil
    environment.platform_outputs = '{}'
    environment.status = :PENDING

    environment.candidates = candidates.map(&:dup)
    environment.stacks = stacks.map(&:dup)
    environment.deployments = deployments.map(&:dup)

    environment
  end

  def consul
    fail 'consul_addresses does not specified' unless consul_addresses

    options = CloudConductor::Config.consul.options.save.merge(token: blueprint_history.consul_secret_key)
    Consul::Client.new(consul_addresses, CloudConductor::Config.consul.port, options)
  end

  def event
    fail 'consul_addresses does not specified' unless consul_addresses

    options = CloudConductor::Config.consul.options.save.merge(token: blueprint_history.consul_secret_key)
    CloudConductor::Event.new(consul_addresses, CloudConductor::Config.consul.port, options)
  end

  def destroy_stacks_in_background
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        destroy_stacks
      end
    end
  end

  def destroy_stacks
    return if stacks.empty?

    builder = CloudConductor::Builders.builder(stacks.first.cloud, self)
    builder.destroy
  end

  def latest_deployments
    deployments_each_application = deployments.group_by { |deployment| deployment.application_history.application_id }.values
    deployments_each_application.map do |deployments|
      deployments.sort_by(&:updated_at).last
    end
  end

  private

  def cfn_parameters(pattern_name)
    pattern_mappings = JSON.parse(template_parameters)[pattern_name] || {}
    cfn_mappings = pattern_mappings['cloud_formation'] || {}
    cfn_mappings.each_with_object({}) do |(k, v), h|
      h[k] = v['value']
    end
  end
end
