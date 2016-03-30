require 'rubygems'
require 'simplecov'
require 'simplecov-rcov'

ENV['RAILS_ENV'] ||= 'test'
require ::File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'pry'

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }
FactoryGirl.definition_file_paths = [::File.expand_path('../factories', __FILE__)]
ActiveRecord::Migration.maintain_test_schema!

SimpleCov.start do
  coverage_dir 'tmp/coverage'
  formatter SimpleCov::Formatter::RcovFormatter
end

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.example_status_persistence_file_path = './tmp/examples.txt'

  config.before :all do
    FactoryGirl.factories.clear
    FactoryGirl.find_definitions
    FactoryGirl.reload
    FactoryGirl::SyntaxRunner.class_eval do
      include RSpec::Mocks::ExampleMethods
    end
  end

  config.before :suite do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with :truncation
  end

  config.before :each do
    DatabaseCleaner.start
  end

  config.after :each do
    DatabaseCleaner.clean
  end

  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    # be_bigger_than(2).and_smaller_than(4).description
    #   # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #   # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    # mocks.verify_partial_doubles = true
    mocks.verify_partial_doubles = false
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random
end
