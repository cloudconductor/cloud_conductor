module ApiSpecHelper
  include Rack::Test::Methods
  include ModelSpecHelper

  shared_context 'default_api_settings' do
    subject { send(method, url, request_params, rack_env) }
    let(:params) { Hash.new }
    let(:auth_token) { nil }
    let(:request_params) { params.merge(auth_token: auth_token) }
    let(:rack_env) { default_rack_env }
    include_context 'default_resources'
    include_context 'default_accounts'
  end

  shared_context 'default_accounts' do
    let(:admin_account) { FactoryGirl.create(:account, :admin) }
    let(:normal_account) { FactoryGirl.create(:account) }
    let(:project_owner_account) { FactoryGirl.create(:account, assign_project: project, role: :administrator) }
    let(:project_operator_account) { FactoryGirl.create(:account, assign_project: project, role: :operator) }
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
    it 'returns 200 and expected response body' do
      expect(subject.body).to match_json_expression(result)
      expect(subject.status).to be(200)
    end
  end

  shared_examples_for '201 Created' do
    it 'returns 201 and expected response body' do
      expect(subject.body).to match_json_expression(result)
      expect(subject.status).to be(201)
    end
  end

  shared_examples_for '202 Accepted' do
    it 'returns 202 and expected response body' do
      expect(subject.body).to match_json_expression(result)
      expect(subject.status).to be(202)
    end
  end

  shared_examples_for '204 No Content' do
    it 'returns 204 and empty response body' do
      expect(subject.body).to be_empty
      expect(subject.status).to be(204)
    end
  end

  shared_examples_for '400 BadRequest' do
    it 'return 400 and bad request message' do
      expect(subject.status).to be(400)
    end
  end

  shared_examples_for '401 Unauthorized' do
    it 'returns 401 and unauthorized message' do
      expect(subject.body).to match_json_expression(error: 'Requires valid auth_token.')
      expect(subject.status).to be(401)
    end
  end

  shared_examples_for '403 Forbidden' do
    it 'returns 403 and forbidden message' do
      expect(subject.body).to match_json_expression(error: 'You are not authorized to access this page.')
      expect(subject.status).to be(403)
    end
  end

  shared_examples_for '404 Not Found' do
    it 'returns 404 and not found message' do
      expect(subject.status).to be(404)
    end
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

  def format_iso8601(object)
    JSON.parse(object.to_json)
  end
end
