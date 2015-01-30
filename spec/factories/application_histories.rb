FactoryGirl.define do
  factory :application_history, class: ApplicationHistory do
    domain 'app.example.com'
    type 'dynamic'
    protocol 'git'
    url 'https://example.com/app_repository.git'
    revision 'master'
    pre_deploy 'echo "pre_deploy"'
    post_deploy 'echo "post_deploy"'
    parameters '{ "key": "value" }'
  end

  before(:create) do
    ApplicationHistory.skip_callback :save, :before, :consul_request
  end

  after(:create) do
    ApplicationHistory.set_callback :save, :before, :consul_request, if: -> { status(false) == :NOT_YET && application.system.ip_address }
  end
end
