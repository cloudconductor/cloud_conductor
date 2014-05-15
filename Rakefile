require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'
require './src/helpers/loader'

environment = ENV['RAILS_ENV'] || :development

ActiveRecord::Tasks::DatabaseTasks.env = environment
ActiveRecord::Base.configurations = YAML.load_file('config/database.yml')
ActiveRecord::Base.establish_connection environment.to_sym
