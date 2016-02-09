class System < ActiveRecord::Base
  belongs_to :project
  belongs_to :primary_environment, class: Environment
  has_many :applications, dependent: :destroy
  has_many :environments, dependent: :destroy

  validates :project, presence: true
  validates :name, presence: true, uniqueness: true

  before_save :update_dns, if: -> { primary_environment && domain }

  after_rollback do
    primary_environment && primary_environment.update_columns(status: :ERROR)
  end

  def update_dns
    dns_client = CloudConductor::DNSClient.new
    dns_client.update domain, primary_environment.ip_address.split(/,\s*/).first
  end
end
