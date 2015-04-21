class ApplicationHistory < ActiveRecord::Base
  self.inheritance_column = nil
  belongs_to :application
  has_many :deployments, dependent: :destroy, inverse_of: :application_history

  validates_associated :application
  validates_presence_of :application, :type, :protocol, :url
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

  def allocate_version
    today = Date.today.strftime('%Y%m%d')

    if /#{today}-(\d+)/.match application.latest_version
      version_num = (Regexp.last_match[1].to_i + 1).to_s.rjust(3, '0')
      self.version = "#{today}-#{version_num}"
    else
      self.version = "#{today}-001"
    end
  end

  def payload
    payload = {
      cloudconductor: {
        applications: {
        }
      }
    }

    application_payload = {}
    application_payload[:type] = type
    application_payload[:version] = version
    application_payload[:protocol] = protocol
    application_payload[:url] = url
    application_payload[:revision] = revision if revision
    application_payload[:pre_deploy] = pre_deploy if pre_deploy
    application_payload[:post_deploy] = post_deploy if post_deploy
    application_payload[:parameters] = JSON.parse(parameters || '{}', symbolize_names: true)

    payload[:cloudconductor][:applications][application.name] = application_payload
    payload
  end
end
