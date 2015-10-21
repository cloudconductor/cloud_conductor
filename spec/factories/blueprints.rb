FactoryGirl.define do
  factory :blueprint, class: Blueprint do
    project
    sequence(:name) { |n| "blueprint-#{n}" }
    description 'blueprint description'
  end
end
