FactoryGirl.define do
  factory :blueprint, class: Blueprint do
    sequence(:name) { |n| "blueprint-#{n}" }
  end
end
