FactoryGirl.define do
  factory :deployment, class: Deployment do
    environment
    application_history

    after(:build) do |deployment, _evaluator|
      allow(deployment).to receive(:consul_request)
    end
  end
end
