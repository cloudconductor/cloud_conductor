class System < ActiveRecord::Base
  belongs_to :project
  belongs_to :primary_environment, class: Environment
  has_many :applications, dependent: :destroy
  has_many :environments, dependent: :destroy

  validates :project, presence: true
  validates :name, presence: true, uniqueness: true

  before_save :update_dns, if: -> { primary_environment && domain }
  before_save :enable_monitoring, if: -> { primary_environment && domain && CloudConductor::Config.zabbix.enabled }

  def update_dns
    dns_client = CloudConductor::DNSClient.new
    dns_client.update domain, primary_environment.ip_address
  end

  def enable_monitoring
    zabbix_client = CloudConductor::ZabbixClient.new
    zabbix_client.register self
  end
end
