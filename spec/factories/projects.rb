FactoryGirl.define do
  factory :project, class: Project do
    sequence(:name) { |n| "project_#{n}" }
    description 'Project Description'

    transient do
      owner nil
    end

    after(:create) do |project, evaluator|
      unless evaluator.owner.nil?
        role = project.roles.find do |role|
          role.name == 'administrator'
        end || FactoryGirl.create(:role, project: project, name: 'administrator')
        assignment = FactoryGirl.build(:assignment, project: project, account: evaluator.owner, roles: [role])
        assignment.save!
      end
    end
  end
end
