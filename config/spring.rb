Spring.after_fork do
  if Rails.env == 'test'
    RSpec.configure do |config|
      config.seed = rand(0xFFFF)
    end
  end
end
