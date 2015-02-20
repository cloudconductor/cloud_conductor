class Blueprint < ActiveRecord::Base
  belongs_to :project
  has_many :patterns, dependent: :destroy, inverse_of: :blueprint
  accepts_nested_attributes_for :patterns

  validates_presence_of :name, :project, :patterns

  before_save :update_consul_secret_key

  def update_consul_secret_key
    if !consul_secret_key && CloudConductor::Config.consul.options.acl
      status, stdout, stderr = systemu('consul keygen')
      fail "consul keygen failed.\n#{stderr}" unless status.success?
      self.consul_secret_key = stdout.chomp
    else
      self.consul_secret_key = ''
    end
  end
end
