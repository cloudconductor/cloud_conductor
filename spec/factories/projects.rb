FactoryGirl.define do
  factory :project, class: Project do
    sequence(:name) { |n| "project_#{n}" }
    description 'Project Description'

    transient do
      owner nil
    end

    after(:create) do |project, evaluator|
      unless evaluator.owner.nil?
        FactoryGirl.create(:assignment, project: project, account: evaluator.owner, role: :administrator)
      end
    end
  end
end
