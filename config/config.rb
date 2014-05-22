environment = (ENV['RACK_ENV'] || ENV['RAILS_ENV'] || :development).to_sym

# log settings
case environment
when :production
  log_file 'log/conductor_production.log'
  log_level :warn
when :development
  log_file 'log/conductor_development.log'
  log_level :debug
when :test
  log_file STDOUT
  log_level :debug
end
