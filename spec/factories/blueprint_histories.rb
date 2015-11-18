FactoryGirl.define do
  factory :blueprint_history, class: BlueprintHistory do
    blueprint
    sequence(:version) { |n| n }

    after(:build) do |blueprint_history, _evaluator|
      allow(blueprint_history).to receive(:build_pattern_snapshots)
    end
  end
end
