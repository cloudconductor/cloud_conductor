FactoryGirl.define do
  factory :blueprint_history, class: BlueprintHistory do
    blueprint
    sequence(:version) { |n| n }

    before(:create) do
      BlueprintHistory.skip_callback :create, :before, :build_pattern_snapshots
    end

    after(:create) do
      BlueprintHistory.set_callback :create, :before, :build_pattern_snapshots
    end
  end
end
