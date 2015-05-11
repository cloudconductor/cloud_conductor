FactoryGirl.define do
  factory :application_history, class: ApplicationHistory do
    application
    type 'dynamic'
    protocol 'git'
    url 'https://example.com/app_repository.git'
    revision 'master'
    pre_deploy 'echo "pre_deploy"'
    post_deploy 'echo "post_deploy"'
    parameters '{"some_key": "some_value"}'
  end
end
