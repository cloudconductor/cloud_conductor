class ApplicationHistory < ActiveRecord::Base
  self.inheritance_column = nil
  belongs_to :application

  validates_associated :application
  validates_presence_of :domain, :type, :protocol, :url
  validates :protocol, inclusion: { in: %w(http https git) }
  validates :url, format: { with: URI.regexp }
  validates_each :parameters do |record, attr, value|
    begin
      JSON.parse(value) unless value.nil?
    rescue JSON::ParserError
      record.errors.add(attr, 'is malformed or invalid json string')
    end
  end

  before_save :allocate_version, unless: -> { version }
  before_save :consul_request, if: -> { !deployed? && application.system.ip_address }
  before_save :update_status, if: -> { status(false) == :PROGRESS }

  after_initialize do
    self.status ||= :NOT_YET
  end

  def status(consul = true) # rubocop:disable CyclomaticComplexity
    status = super() && super().to_sym
    return status unless status == :PROGRESS && consul

    return :NOT_YET unless event

    event_log = application.system.event.find(event)
    return :PROGRESS unless event_log.finished?
    return :DEPLOYED if event_log.success?

    :ERROR
  end

  def update_status
    self.status = status
  end

  def allocate_version
    today = Date.today.strftime('%Y%m%d')

    if /#{today}-(\d+)/.match application.latest_version
      version_num = (Regexp.last_match[1].to_i + 1).to_s.rjust(3, '0')
      self.version = "#{today}-#{version_num}"
    else
      self.version = "#{today}-001"
    end
  end

  def application_payload
    payload = {}
    payload[:domain] = domain
    payload[:type] = type
    payload[:version] = version
    payload[:protocol] = protocol
    payload[:url] = url
    payload[:revision] = revision if revision
    payload[:pre_deploy] = pre_deploy if pre_deploy
    payload[:post_deploy] = post_deploy if post_deploy

    payload[:parameters] = JSON.parse(parameters || '{}', symbolize_names: true)

    payload
  end

  def consul_request
    payload = {
      cloudconductor: {
        applications: {
        }
      }
    }

    payload[:cloudconductor][:applications][application.name] = application_payload

    self.status = :PROGRESS
    self.event = application.system.event.fire(:deploy, payload)
  end

  def deployed?
    status == :DEPLOYED
  end

  def dup
    history = super
    history.status = :NOT_YET
    history
  end
end
