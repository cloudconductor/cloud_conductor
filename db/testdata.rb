# Create Admin Account
Account.where(email: 'admin@example.com').first_or_create!(
  email: 'admin@example.com',
  name: 'Administrator',
  password: 'password',
  password_confirmation: 'password',
  admin: true
)

# Create Guest Account
Account.where(email: 'guest@example.com').first_or_create!(
  email: 'guest@example.com',
  name: 'Guest User',
  password: 'password',
  password_confirmation: 'password',
  admin: false
)

# Create Project X
project_x = Project.find_or_create_by!(
  name: 'Project X',
  description: 'Project X description'
)

# Create Account and Assign Project X as Administrator
x_admin = Account.where(email: 'x_admin@example.com').first_or_create!(
  email: 'x_admin@example.com',
  name: 'Project X Administrator',
  password: 'password',
  password_confirmation: 'password',
  admin: false
)
project_x.assign_project_member(x_admin, :administrator)

# Create Account and Assign Project X as Operator
x_operator = Account.where(email: 'x_operator@example.com').first_or_create!(
  email: 'x_operator@example.com',
  name: 'Project X Operator',
  password: 'password',
  password_confirmation: 'password',
  admin: false
)
project_x.assign_project_member(x_operator)

# Create Project X Resources

# Cloud
cloud = Cloud.find_or_create_by!(
  name: 'AWS Tokyo Region',
  type: 'aws',
  entry_point: 'ap-northeast-1',
  key: 'dummy_access_key',
  secret: 'dummy_secret_key',
  project_id: project_x.id
)

# Blueprint and Pattern
Pattern.skip_callback(:save, :before, :execute_packer)
Blueprint.skip_callback(:create, :before, :update_consul_secret_key)
blueprint = Blueprint.where(name: 'tomcat').first_or_create!(
  project_id: project_x.id,
  name: 'tomcat',
  description: 'Apache, Tomcat, PostgreSQL',
  consul_secret_key: 'xxxxxxxx',
  patterns_attributes: [{
    url: 'https://github.com/cloudconductor-patterns/tomcat_pattern.git',
    revision: 'master'
  }]
)
blueprint.patterns.first.update(
  name: 'tomcat_pattern',
  type: 'platform'
)
Pattern.set_callback(:save, :before, :execute_packer)
Blueprint.set_callback(:create, :before, :update_consul_secret_key)

# System
System.skip_callback(:save, :before, :update_dns)
System.skip_callback(:save, :before, :enable_monitoring)
system = System.find_or_create_by!(
  project_id: project_x.id,
  name: 'sample_system_1',
  description: 'sample_system_1',
  domain: 'sample.example.com',
)
System.set_callback(:save, :before, :update_dns)
System.set_callback(:save, :before, :enable_monitoring)

# Environment and Stack
Environment.skip_callback(:save, :before, :create_stacks)
environment = Environment.where(name: 'sample_environment_1').first_or_create!(
  system_id: system.id,
  blueprint_id: blueprint.id,
  name: 'sample_environment_1',
  description: 'sample_environment_1',
  candidates_attributes: [{
    cloud_id: cloud.id,
    priority: 10
  }],
  stacks_attributes: [{
    name: 'tomcat_pattern',
    template_parameters: '{}',
    parameters: '{}'
  }]
)
environment.update!(status: :CREATE_COMPLETE)
Stack.set_callback(:save, :before, :create_stack)
Environment.set_callback(:save, :before, :create_stacks)

# Application and Application History
ApplicationHistory.skip_callback(:save, :before, :consul_request)
ApplicationHistory.skip_callback(:save, :before, :update_status)
application = Application.where(name: 'sample_app').first_or_create!(
  system_id: system.id,
  name: 'sample_app',
  description: 'sample_app'
)
application.histories.where(domain: 'sample.example.com').first_or_create!(
  domain: 'sample.example.com',
  url: 'http://www.example.com/sample_app.tar.gz',
  revision: 'master',
  protocol: 'http',
  type: 'dynamic',
  pre_deploy: '',
  post_deploy: '',
  parameters: '{}'
)
ApplicationHistory.set_callback(:save, :before, :consul_request)
ApplicationHistory.set_callback(:save, :before, :update_status)
