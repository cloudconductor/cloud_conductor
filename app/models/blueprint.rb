class Blueprint < ActiveRecord::Base
  belongs_to :project
  has_many :patterns, dependent: :destroy, inverse_of: :blueprint
  accepts_nested_attributes_for :patterns

  validates_presence_of :name, :project, :patterns
  validates :name, uniqueness: true

  validate do
    begin
      patterns.each(&:set_metadata_from_repository)
      unless patterns.any? { |pattern| pattern.type == 'platform' }
        errors.add(:patterns, 'don\'t contain platform pattern')
      end
    rescue => e
      errors.add(:patterns, "is invalid(#{e.message})")
    end
  end

  before_create :set_consul_secret_key

  def set_consul_secret_key
    return unless CloudConductor::Config.consul.options.acl
    self.consul_secret_key ||= generate_consul_secret_key
  end

  def generate_consul_secret_key
    SecureRandom.base64(16)
  end

  def status
    pattern_states = patterns.map(&:status)
    if pattern_states.all? { |status| status == :CREATE_COMPLETE }
      :CREATE_COMPLETE
    elsif pattern_states.any? { |status| status == :ERROR }
      :ERROR
    else
      :PENDING
    end
  end

  def as_json(options = {})
    super({ except: :consul_secret_key, methods: :status }.merge(options))
  end
end
