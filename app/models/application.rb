class Application < ActiveRecord::Base
  belongs_to :system
  has_many :histories, class_name: :ApplicationHistory, dependent: :destroy

  validates_associated :system
  validates_presence_of :name, :system
  validates :name, uniqueness: { scope: :system_id }

  def latest
    histories.last
  end

  def latest_version
    latest.version if latest
  end

  def status
    latest.status if latest
  end

  def as_json(options = {})
    super options.merge(methods: [:latest, :latest_version, :status])
  end

  def dup
    application = super
    application.system = nil
    application
  end
end
