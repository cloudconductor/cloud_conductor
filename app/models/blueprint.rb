class Blueprint < ActiveRecord::Base
  belongs_to :project
  has_many :patterns, dependent: :destroy, inverse_of: :blueprint
  accepts_nested_attributes_for :patterns

  validates_presence_of :name, :project, :patterns
  validates :name, uniqueness: true

  before_create :update_consul_secret_key

  def update_consul_secret_key
    if !consul_secret_key && CloudConductor::Config.consul.options.acl
      status, stdout, stderr = systemu('consul keygen')
      fail "consul keygen failed.\n#{stderr}" unless status.success?
      self.consul_secret_key = stdout.chomp
    else
      self.consul_secret_key = ''
    end
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
    super(options.merge(except: :consul_secret_key, methods: :status))
  end
end
