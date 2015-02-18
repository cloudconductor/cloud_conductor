FactoryGirl.define do
  factory :blueprint, class: Blueprint do
    project
    sequence(:name) { |n| "blueprint-#{n}" }

    transient do
      patterns_count 2
    end

    after(:build) do |blueprint, evaluator|
      blueprint.patterns = create_list(:pattern, evaluator.patterns_count, :platform, blueprint: blueprint) if blueprint.patterns.empty?
    end

    before(:create) do
      Pattern.skip_callback :save, :before, :execute_packer
    end

    after(:create) do
      Pattern.set_callback :save, :before, :execute_packer, if: -> { url_changed? || revision_changed? }
    end
  end
end
