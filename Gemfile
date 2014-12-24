source 'https://rubygems.org'

gem 'rake'

gem 'rack'
gem 'rack-parser'
gem 'sinatra'
gem 'sinatra-contrib'

gem 'sqlite3'
gem 'activerecord'
gem 'activesupport', require: 'active_support/dependencies'
gem 'sinatra-activerecord'
gem 'actionpack'

gem 'mixlib-config'
gem 'mixlib-log'

gem 'aws-sdk'
gem 'fog'
gem 'zbxapi', git: 'https://github.com/cloudconductor-dev/zbxapi.git',
              branch: 'skip-authentication'

gem 'systemu'

gem 'faraday'
gem 'rb-readline'
gem 'unicorn'

gem 'cfn_converter', git: 'https://github.com/cloudconductor/cfn_converter.git',
                     branch: 'develop'

group :development do
  gem 'guard'
  gem 'byebug'
  gem 'pry-byebug'
  gem 'pry-doc'
  gem 'pry-stack_explorer'
  gem 'guard-rubocop'
end

group :test do
  gem 'rspec'
  gem 'rspec-mocks'
  gem 'rspec_junit_formatter'
  gem 'simplecov'
  gem 'simplecov-rcov'
  gem 'database_cleaner'
  gem 'guard-rspec', require: false
  gem 'factory_girl'
  gem 'spork', git: 'https://github.com/sporkrb/spork.git'
  gem 'guard-spork', '~>2'
end
