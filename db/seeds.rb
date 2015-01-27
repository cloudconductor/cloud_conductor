OperatingSystem.find_or_create_by(
  name: 'centos',
  version: '6.5'
)

if Rails.env == 'development'
  Account.where(email: 'admin@example.com').first_or_create!(
    email: 'admin@example.com',
    name: 'Administrator',
    password: 'password',
    password_confirmation: 'password',
    admin: true
  )
end
