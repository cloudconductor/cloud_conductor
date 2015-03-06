desc 'Register first administrator account'
task 'register:admin' => :environment do
  puts 'Input administrator account information.'
  print '  Email: '
  email = STDIN.gets.chomp
  print '  Name: '
  name = STDIN.gets.chomp
  print '  Password: '
  password = STDIN.noecho(&:gets).chomp
  puts
  print '  Password Confirmation: '
  password_confirmation = STDIN.noecho(&:gets).chomp
  puts
  begin
    Account.create!(
      email: email,
      name: name,
      password: password,
      password_confirmation: password_confirmation,
      admin: true
    )
    puts "Administrator account registered to #{Rails.env} environment successfully"
  rescue ActiveRecord::RecordInvalid => e
    puts "[ERROR] #{e.message}"
  end
end
