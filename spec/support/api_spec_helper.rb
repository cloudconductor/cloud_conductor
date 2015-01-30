module ApiSpecHelper
  include Rack::Test::Methods

  shared_context 'api' do
    subject { send(method, url, request_params, rack_env) }
    let(:params) { Hash.new }
    let(:auth_token) { nil }
    let(:request_params) { params.merge(auth_token: auth_token) }
    let(:rack_env) { default_rack_env }
  end

  shared_context 'default_accounts' do
    let(:project) { FactoryGirl.create(:project) }
    let(:admin_account) { FactoryGirl.create(:account, :admin) }
    let(:normal_account) { FactoryGirl.create(:account) }
    let(:project_owner_account) do
      account = FactoryGirl.create(:account)
      FactoryGirl.create(:assignment, :admin, project: project, account: account)
      account
    end
    let(:project_operator_account) do
      account = FactoryGirl.create(:account)
      FactoryGirl.create(:assignment, project: project, account: account)
      account
    end
  end

  shared_context 'normal_auth_token', normal: true do
    let(:auth_token) { normal_account.authentication_token }
  end

  shared_context 'admin_auth_token', admin: true do
    let(:auth_token) { admin_account.authentication_token }
  end

  shared_context 'project_owner_auth_token', project_owner: true do
    let(:auth_token) { project_owner_account.authentication_token }
  end

  shared_context 'project_operator_auth_token', project_operator: true do
    let(:auth_token) { project_operator_account.authentication_token }
  end

  shared_examples_for '200 OK' do
    it { expect(subject.status).to be(200) }
    it { expect(subject.body).to match_json_expression(result) }
  end

  shared_examples_for '201 Accepted' do
    it { expect(subject.status).to be(201) }
    it { expect(subject.body).to match_json_expression(result) }
  end

  shared_examples_for '204 No Content' do
    it { expect(subject.status).to be(204) }
    it { expect(subject.body).to be_empty }
  end

  shared_examples_for '401 Unauthorized' do
    it { expect(subject.status).to be(401) }
    it { expect(subject.body).to match_json_expression(error: 'Unauthorized') }
  end

  shared_examples_for '403 Forbidden' do
    it { expect(subject.status).to be(403) }
    it { expect(subject.body).to match_json_expression(error: 'You are not authorized to access this page.') }
  end

  def app
    Rails.application
  end

  def default_rack_env
    {
      'HTTP_HOST' => 'api.example.com',
      'HTTP_ACCEPT' => 'application/json'
    }
  end

  def api_attributes(object)
    JSON.parse(object.to_json)
  end
end
