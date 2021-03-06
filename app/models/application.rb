class Application < ActiveRecord::Base
  belongs_to :system
  has_many :histories, class_name: :ApplicationHistory, dependent: :destroy

  validates_associated :system
  validates_presence_of :name, :system
  validates :name, uniqueness: { scope: :system_id }

  scope :select_by_project_id, -> (project_id) { joins(:system).where(systems: { project_id: project_id }) }

  def project
    system.project
  end

  def latest
    histories.last
  end

  def latest_version
    latest.version if latest
  end

  def dup
    application = super
    application.system = nil
    application
  end
end
