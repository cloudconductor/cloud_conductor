# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)

logger = ::Logger.new(CloudConductor::Config.access_log_path)
def logger.write(msg)
  self << msg
end
use Rack::CommonLogger, logger
run Rails.application
