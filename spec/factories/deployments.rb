FactoryGirl.define do
  factory :deployment, class: Deployment do
    environment
    application_history
  end

  before(:create) do
    Deployment.skip_callback :save, :before, :consul_request
    Deployment.skip_callback :save, :before, :update_status
  end

  after(:create) do
    Deployment.set_callback :save, :before, :consul_request, if: -> { status == :NOT_YET && environment.ip_address }
    Deployment.set_callback :save, :before, :update_status
  end
end
