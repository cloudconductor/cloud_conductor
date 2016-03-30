FactoryGirl.define do
  factory :blueprint_history, class: BlueprintHistory do
    transient do
      project { build(:project) }
    end

    blueprint { build(:blueprint, project: project) }
    sequence(:version) { |n| n }

    after(:build) do |blueprint_history, _evaluator|
      allow(blueprint_history).to receive(:set_ssh_private_key)
      allow(blueprint_history).to receive(:build_pattern_snapshots)
    end
  end
end
