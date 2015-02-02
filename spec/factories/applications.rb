FactoryGirl.define do
  factory :application, class: Application do
    sequence(:name) { |n| "application_#{n}" }
    system { create(:system) }
  end
end
