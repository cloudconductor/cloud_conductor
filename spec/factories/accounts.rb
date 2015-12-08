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
        project = evaluator.assign_project
        role = project.roles.find_by(name: evaluator.role) || FactoryGirl.create(:role, name: evaluator.role)
        FactoryGirl.create(:assignment, project: evaluator.assign_project, account: account, roles: [role])
      end
    end
  end
end
