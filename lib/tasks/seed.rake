desc 'load test data to development environment'
task 'db:seed:development' => :environment do
  load(File.join(Rails.root, 'db', 'testdata.rb')) if Rails.env.development?
end
