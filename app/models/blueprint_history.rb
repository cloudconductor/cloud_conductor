class BlueprintHistory < ActiveRecord::Base
  belongs_to :blueprint
  has_many :patterns, class_name: :PatternSnapshot, dependent: :destroy

  validates_presence_of :blueprint

  before_create :set_consul_secret_key
  before_create :set_version
  before_create :freeze_patterns

  def status
    if patterns.any? { |pattern| pattern.status == :ERROR }
      :ERROR
    elsif patterns.all? { |pattern| pattern.status == :CREATE_COMPLETE }
      :CREATE_COMPLETE
    else
      :PROGRESS
    end
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

  def freeze_patterns
    blueprint.blueprint_patterns.each do |relation|
      patterns.build(
        url: relation.pattern.url,
        revision: relation.revision || relation.pattern.revision,
        os_version: relation.os_version
      )
    end
  end
end
