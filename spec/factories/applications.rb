FactoryGirl.define do
  factory :application, class: Application do
    system
    sequence(:name) { |n| "application_#{n}" }
    description 'application description'
    domain 'app.example.com'
  end
end
