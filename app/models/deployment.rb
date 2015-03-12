class Deployment < ActiveRecord::Base
  belongs_to :environment
  belongs_to :application_history

  validates_presence_of :environment, :application_history

  before_save :consul_request
  after_initialize -> { self.status ||= :NOT_DEPLOYED }
  after_find :update_status
  validate do
    errors.add(:environment, 'status does not create_complete') if environment && environment.status != :CREATE_COMPLETE
  end

  def consul_request
    if environment.ip_address
      self.status = :PROGRESS
      self.event = environment.event.fire(:deploy, application_history.payload)
    else
      self.status = :ERROR
    end
  end

  def update_status
    return if new_record? || status.to_sym != :PROGRESS
    event_log = environment.event.find(event)
    if event_log.nil?
      update_columns(status: :ERROR)
    elsif event_log.finished?
      new_status = event_log.success? ? :DEPLOY_COMPLETE : :ERROR
      update_columns(status: new_status)
    end
  rescue
    update_columns(status: :ERROR)
  end

  def dup
    deployment = super
    deployment.environment = nil
    deployment.status = :NOT_DEPLOYED
    deployment
  end
end
