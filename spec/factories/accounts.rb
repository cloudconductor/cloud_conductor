FactoryGirl.define do
  factory :account, class: Account do
    email { "#{SecureRandom.hex(8)}@example.com" }
    name { 'UserName' }
    password 'password'
    password_confirmation 'password'
    admin false

    trait :admin do
      admin true
    end

    transient do
      assign_project nil
      role :operator
    end

    after(:create) do |account, evaluator|
      unless evaluator.assign_project.nil?
        FactoryGirl.create(:assignment, project: evaluator.assign_project, account: account, role: evaluator.role)
      end
    end
  end
end
