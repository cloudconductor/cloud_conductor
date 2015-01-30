FactoryGirl.define do
  factory :application, class: Application do
    sequence(:name) { |n| "application_#{n}" }
    system { create(:system, ip_address: '127.0.0.1') }

    after do |application|
      create(:application_history, application: application)
    end
  end
end
