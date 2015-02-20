require 'open-uri'

class Environment < ActiveRecord::Base
  belongs_to :system
  belongs_to :blueprint
  has_many :candidates, dependent: :destroy, inverse_of: :environment
  has_many :clouds, through: :candidates
  has_many :stacks
  accepts_nested_attributes_for :candidates

  before_destroy :destroy_stacks, unless: -> { stacks.empty? }

  before_save :update_dns, if: -> { ip_address }
  before_save :enable_monitoring, if: -> { monitoring_host && monitoring_host_changed? }

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

  after_create do
    blueprint.patterns.each do |pattern|
      stacks.create!(name: pattern.name, pattern: pattern, cloud: candidates.primary.cloud)
    end
  end

  def status
    super && super.to_sym
  end

  def as_json(options = {})
    super options.merge(methods: [:status])
  end

  def dup
    environment = super

    basename = name.sub(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, '')
    environment.name = "#{basename}-#{SecureRandom.uuid}"
    environment.ip_address = nil
    environment.monitoring_host = nil
    environment.template_parameters = '{}'

    environment.candidates = candidates.map(&:dup)
    environment.stacks = stacks.map(&:dup)

    environment
  end

  def enable_monitoring
    zabbix_client = CloudConductor::ZabbixClient.new
    zabbix_client.register self
  end

  def update_dns
    dns_client = CloudConductor::DNSClient.new
    dns_client.update domain, ip_address
  end

  def consul
    fail 'ip_address does not specified' unless ip_address

    token = stacks.first.pattern.consul_secret_key

    options = CloudConductor::Config.consul.options.save.merge(token: token)
    Consul::Client.new(ip_address, CloudConductor::Config.consul.port, options)
  end

  def event
    fail 'ip_address does not specified' unless ip_address

    token = stacks.first.pattern.consul_secret_key

    options = CloudConductor::Config.consul.options.save.merge(token: token)
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

  private

  def stack_destroyed?
    lambda do |stack|
      return true unless stack.exist?
      [:DELETE_COMPLETE, :DELETE_FAILED].include? stack.cloud.client.get_stack_status(stack.name)
    end
  end
end
