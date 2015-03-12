FactoryGirl.define do
  factory :deployment, class: Deployment do
    environment
    application_history
  end

  before(:create) do
    Deployment.skip_callback :save, :before, :consul_request
  end

  after(:create) do
    Deployment.set_callback :save, :before, :consul_request, if: -> { status == :NOT_DEPLOYED }
  end
end
