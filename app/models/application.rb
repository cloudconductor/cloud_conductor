class Application < ActiveRecord::Base
  belongs_to :system
  has_many :histories, class_name: :ApplicationHistory, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :system_id }
  validates :system, presence: true

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
