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

  def project
    application.project
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

  def payload
    json = {
      cloudconductor: {
        applications: {
        }
      }
    }

    application_json = {}
    application_json[:type] = type
    application_json[:version] = version
    application_json[:protocol] = protocol
    application_json[:url] = url
    application_json[:revision] = revision if revision
    application_json[:pre_deploy] = pre_deploy if pre_deploy
    application_json[:post_deploy] = post_deploy if post_deploy
    application_json[:parameters] = JSON.parse(parameters || '{}', symbolize_names: true)

    json[:cloudconductor][:applications][application.name] = application_json

    payload = {}
    payload["cloudconductor/applications/#{application.name}"] = json
    payload
  end
end
