FactoryGirl.define do
  factory :blueprint_history, class: BlueprintHistory do
    blueprint
    sequence(:version) { |n| n }

    before(:create) do
      BlueprintHistory.skip_callback :create, :before, :freeze_patterns
    end

    after(:create) do
      BlueprintHistory.set_callback :create, :before, :freeze_patterns
    end
  end
end
