FactoryGirl.define do
  factory :assignment, class: Assignment do
    project
    account
    roles { [project.roles.find_by(name: 'operator') || create(:role, name: 'operator')] }

    trait :admin do
      roles { [project.roles.find_by(name: 'administrator') || create(:role, name: 'administrator')] }
    end
  end
end
