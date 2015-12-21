FactoryGirl.define do
  factory :deployment, class: Deployment do
    environment { build(:environment) }
    application_history { build(:application_history, system: environment.system) }

    after(:build) do |deployment, _evaluator|
      allow(deployment).to receive(:consul_request)
    end
  end
end
