module ApplicationHelper
  def logger
    Rails.application.config.application_logger
  end
end
