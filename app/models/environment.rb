require 'open-uri'

class Environment < ActiveRecord::Base # rubocop:disable ClassLength
  belongs_to :system
  belongs_to :blueprint
  has_many :candidates, dependent: :destroy, inverse_of: :environment
  has_many :clouds, through: :candidates
  has_many :stacks, validate: false
  has_many :deployments, dependent: :destroy, inverse_of: :environment
  has_many :application_histories, through: :deployments
  accepts_nested_attributes_for :candidates
  accepts_nested_attributes_for :stacks

  before_destroy :destroy_stacks, unless: -> { stacks.empty? }

  before_save :create_stacks, if: -> { blueprint_id_changed? }

  validates_presence_of :system, :candidates, :blueprint
  validates :name, presence: true, uniqueness: true

  validate do
    clouds = candidates.map(&:cloud)
    errors.add(:clouds, 'can\'t contain duplicate cloud in clouds attribute') unless clouds.size == clouds.uniq.size
  end

  after_initialize do
    self.template_parameters ||= '{}'
    self.status ||= :PENDING
  end

  def create_stacks
    primary_cloud = candidates.sort.first.cloud

    self.stacks = blueprint.patterns.map do |pattern|
      stack = stacks.find { |stack| stack.basename == pattern.name }
      unless stack
        stack = Stack.new(environment: self, name: pattern.name)
        stacks << stack
      end

      stack.pattern = pattern
      stack.cloud = primary_cloud
      stack
    end
    true
  end

  def status
    super && super.to_sym
  end

  def basename
    name.sub(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, '')
  end

  def as_json(options = {})
    super options.merge(methods: [:status])
  end

  def dup
    environment = super

    basename = name.sub(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, '')
    environment.name = "#{basename}-#{SecureRandom.uuid}"
    environment.ip_address = nil
    environment.template_parameters = '{}'
    environment.status = :PENDING

    environment.candidates = candidates.map(&:dup)
    environment.stacks = stacks.map(&:dup)
    environment.deployments = deployments.map(&:dup)

    environment
  end

  def consul
    fail 'ip_address does not specified' unless ip_address

    options = CloudConductor::Config.consul.options.save.merge(token: blueprint.consul_secret_key)
    Consul::Client.new(ip_address, CloudConductor::Config.consul.port, options)
  end

  def event
    fail 'ip_address does not specified' unless ip_address

    options = CloudConductor::Config.consul.options.save.merge(token: blueprint.consul_secret_key)
    CloudConductor::Event.new(ip_address, CloudConductor::Config.consul.port, options)
  end

  TIMEOUT = 1800
  def destroy_stacks
    platforms = stacks.select(&:platform?)
    optionals = stacks.select(&:optional?)
    stacks.delete_all

    Thread.new do
      begin
        sleep 1
        ActiveRecord::Base.connection_pool.disconnect!
        optionals.each(&:destroy)

        Timeout.timeout(TIMEOUT) do
          sleep 10 until optionals.all?(&stack_destroyed?)
        end
      rescue Timeout::Error
        Log.warn "Exceeded timeout while destroying stacks #{optionals}"
      ensure
        platforms.each(&:destroy)
      end
    end
  end

  def update_attributes_and_stacks!(attributes)
    attributes[:stacks_attributes].each do |stack_attributes|
      stack = stacks.find { |stack| stack.basename == stack_attributes[:name] }
      next unless stack
      stack_attributes[:id] = stack.id
      stack.template_parameters = stack_attributes[:template_parameters]
      stack.status = :PENDING
    end
    update_attributes! attributes
  end

  private

  def stack_destroyed?
    lambda do |stack|
      return true unless stack.exist?
      [:DELETE_COMPLETE, :DELETE_FAILED].include? stack.cloud.client.get_stack_status(stack.name)
    end
  end
end
