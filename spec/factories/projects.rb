FactoryGirl.define do
  factory :project, class: Project do
    sequence(:name) { |n| "project_#{n}" }
    description 'Project Description'
  end
end
