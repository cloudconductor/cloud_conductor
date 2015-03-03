class Stack < ActiveRecord::Base # rubocop:disable ClassLength
  belongs_to :environment
  belongs_to :pattern
  belongs_to :cloud

  validates :name, presence: true, uniqueness: { scope: :cloud_id }
  validates_presence_of :environment, :pattern, :cloud

  validates_each :template_parameters, :parameters do |record, attr, value|
    begin
      JSON.parse(value) unless value.nil?
    rescue JSON::ParserError
      record.errors.add(attr, 'is malformed or invalid json string')
    end
  end

  validate do
    errors.add(:pattern, 'can\'t use pattern that contains uncompleted image') if pattern && pattern.status != :CREATE_COMPLETE
  end

  scope :in_progress, -> { where(status: :PROGRESS) }
  scope :created, -> { where(status: :CREATE_COMPLETE) }

  before_destroy :destroy_stack, unless: -> { pending? }
  before_create :create_stack, if: -> { ready? }
  before_update :update_stack, if: -> { create_complete? }

  after_initialize do
    self.template_parameters ||= '{}'
    self.parameters ||= '{}'
    self.status ||= :PENDING
  end

  def client
    @client ||= cloud.client
  end

  def create_stack
    common_parameters = JSON.parse(environment.template_parameters, symbolize_names: true)
    stack_parameters = JSON.parse(template_parameters, symbolize_names: true)
    client.create_stack name, pattern, common_parameters.deep_merge(stack_parameters)
  rescue Excon::Errors::SocketError
    self.status = :ERROR
    Log.warn "Failed to connect to #{cloud.name}"
  rescue Excon::Errors::Unauthorized, AWS::CloudFormation::Errors::InvalidClientTokenId
    self.status = :ERROR
    Log.warn "Failed to authorize on #{cloud.name}"
  rescue Net::OpenTimeout
    self.status = :ERROR
    Log.warn "Timeout has occurred while creating stack(#{name}) on #{cloud.name}"
  rescue => e
    self.status = :ERROR
    Log.warn("Create stack on #{cloud.name} ... FAILED")
    Log.warn "Unexpected error has occurred while creating stack(#{name}) on #{cloud.name}"
    Log.warn(e)
  else
    self.status = :PROGRESS
    Log.info("Create stack on #{cloud.name} ... SUCCESS")
  end

  def update_stack
    stack_parameters = JSON.parse(template_parameters, symbolize_names: true)
    client.update_stack name, pattern, stack_parameters
  rescue Excon::Errors::SocketError
    self.status = :ERROR
    Log.warn "Failed to connect to #{cloud.name}"
  rescue Excon::Errors::Unauthorized, AWS::CloudFormation::Errors::InvalidClientTokenId
    self.status = :ERROR
    Log.warn "Failed to authorize on #{cloud.name}"
  rescue Net::OpenTimeout
    self.status = :ERROR
    Log.warn "Timeout has occurred while creating stack(#{name}) on #{cloud.name}"
  end

  def basename
    name.sub(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, '')
  end

  def dup
    stack = super

    stack.name = "#{basename}-#{SecureRandom.uuid}"
    stack.status = :PENDING
    stack
  end

  def platform?
    pattern && pattern.type == :platform
  end

  def optional?
    pattern && pattern.type == :optional
  end

  def exist?
    client.get_stack_status name
    true
  rescue
    false
  end

  %i(pending ready progress create_complete error).each do |method|
    define_method "#{method}?" do
      (attributes['status'] || :NIL).to_sym == method.upcase
    end
  end

  def status
    status = super
    return status && status.to_sym unless status && status.to_sym == :PROGRESS

    client.get_stack_status name if client
  rescue
    :ERROR
  end

  def outputs
    client.get_outputs name
  rescue
    {}
  end

  def destroy_stack
    client.destroy_stack name
  rescue => e
    Log.warn "Some error occurred while destroy stack that is #{name} on #{cloud.name}."
    Log.warn "  #{e.message}"
  end

  def payload
    payload = {}
    payload[pattern.name] = JSON.parse(pattern.to_json, symbolize_names: true)
    payload[pattern.name][:user_attributes] = JSON.parse(parameters, symbolize_names: true)

    payload
  end
end
