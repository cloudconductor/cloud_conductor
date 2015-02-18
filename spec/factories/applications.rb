FactoryGirl.define do
  factory :application, class: Application do
    system
    sequence(:name) { |n| "application_#{n}" }
  end
end
