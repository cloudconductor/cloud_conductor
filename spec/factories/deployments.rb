FactoryGirl.define do
  factory :deployment, class: Deployment do
  end

  before(:create) do
    # Deployment.skip_callback :save, :before, :consul_request
  end

  after(:create) do
    # Deployment.set_callback :save, :before, :consul_request, if: -> { status(false) == :NOT_YET && application.system.ip_address }
  end
end
