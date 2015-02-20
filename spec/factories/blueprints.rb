FactoryGirl.define do
  factory :blueprint, class: Blueprint do
    project
    sequence(:name) { |n| "blueprint-#{n}" }
    consul_secret_key ''

    transient do
      patterns_count 2
    end

    after(:build) do |blueprint, evaluator|
      blueprint.patterns = create_list(:pattern, evaluator.patterns_count, :platform, blueprint: blueprint) if blueprint.patterns.empty?
    end

    before(:create) do
      Pattern.skip_callback :save, :before, :execute_packer
      Blueprint.skip_callback :save, :before, :update_consul_secret_key
    end

    after(:create) do
      Pattern.set_callback :save, :before, :execute_packer, if: -> { url_changed? || revision_changed? }
      Blueprint.set_callback :save, :before, :update_consul_secret_key
    end
  end
end
