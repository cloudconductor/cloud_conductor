class BlueprintHistory < ActiveRecord::Base
  belongs_to :blueprint
  has_many :pattern_snapshots, dependent: :destroy

  validates_presence_of :blueprint

  before_create :set_consul_secret_key
  before_create :set_version
  before_create :build_pattern_snapshots

  def project
    blueprint.project
  end

  def status
    if pattern_snapshots.any? { |pattern_snapshot| pattern_snapshot.status == :ERROR }
      :ERROR
    elsif pattern_snapshots.all? { |pattern_snapshot| pattern_snapshot.status == :CREATE_COMPLETE }
      :CREATE_COMPLETE
    else
      :PROGRESS
    end
  end

  def providers
    return {} if pattern_snapshots.empty?

    result = {}
    providers = pattern_snapshots.map do |pattern_snapshot|
      JSON.parse(pattern_snapshot.providers)
    end

    providers.map(&:keys).inject(&:|).each do |cloud|
      providers.each do |provider|
        list = provider[cloud] || []
        result[cloud] ||= list
        result[cloud] = result[cloud] & list
      end
    end

    result.reject { |_key, value| value.empty? }
  end

  def as_json(options = {})
    super({ methods: :status }.merge(options))
  end

  private

  def set_consul_secret_key
    return unless CloudConductor::Config.consul.options.acl
    self.consul_secret_key ||= SecureRandom.base64(16)
  end

  def set_version
    latest = blueprint.histories.last
    self.version = 1
    self.version = latest.version + 1 if latest
  end

  def build_pattern_snapshots
    BlueprintPattern.eager_load(:pattern).where(blueprint_id: blueprint.id).each do |relation|
      pattern_snapshots.build(
        url: relation.pattern.url,
        revision: relation.revision || relation.pattern.revision,
        platform: relation.platform,
        platform_version: relation.platform_version
      )
    end
    pattern_snapshots.each(&:freeze_pattern)

    fail 'Patterns don\'t have usable providers on any cloud' if providers.empty?
  end
end
