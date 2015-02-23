class Deployment < ActiveRecord::Base
  belongs_to :environment
  belongs_to :application_history

  before_save :consul_request, if: -> { status == :NOT_YET && environment.ip_address }
  before_save :update_status

  validates_presence_of :environment, :application_history

  after_initialize do
    self.status ||= :NOT_YET
  end

  def status # rubocop:disable CyclomaticComplexity
    status = super && super.to_sym
    return status unless status == :PROGRESS

    event_log = environment.event.find(event)
    return :PROGRESS unless event_log.finished?
    return :DEPLOYED if event_log.success?

    :ERROR
  rescue
    :ERROR
  end

  def consul_request
    self.status = :PROGRESS
    self.event = environment.event.fire(:deploy, application_history.payload)
  end

  def update_status
    self.status = status
  end

  def dup
    deployment = super
    deployment.environment = nil
    deployment.status = :NOT_YET
    deployment
  end
end
