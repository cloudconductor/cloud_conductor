FactoryGirl.define do
  factory :assignment, class: Assignment do
    role :operator

    trait :admin do
      role :administrator
    end
  end
end
