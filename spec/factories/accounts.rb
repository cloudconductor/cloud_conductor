FactoryGirl.define do
  factory :account, class: Account do
    email { "#{SecureRandom.hex(8)}@example.com" }
    name { 'UserName' }
    password 'password'
    password_confirmation 'password'
    # old_password 'password'
    # new_password 'password'
    # new_password_confirmation 'password'
    admin false

    after(:create) do |account|
      account.ensure_authentication_token!
    end

    trait :admin do
      admin true
    end
  end
end
