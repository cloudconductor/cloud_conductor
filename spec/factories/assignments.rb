FactoryGirl.define do
  factory :assignment, class: Assignment do
    project
    account
    role :operator

    trait :admin do
      role :administrator
    end
  end
end
