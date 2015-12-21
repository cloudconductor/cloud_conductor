describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'ApplicationHistoryAPI' do
    before { application_history }

    describe 'GET /applications/:application_id/histories' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/applications/#{application.id}/histories" }
      let(:result) { format_iso8601(application.histories.map(&:as_json)) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_application_id', admin: true do
        let(:url) { '/api/v1/applications/0/histories' }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        let(:result) { [] }
        it_behaves_like('200 OK')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
      end
    end

    describe 'GET /applications/:application_id/histories/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/applications/#{application.id}/histories/#{application_history.id}" }
      let(:result) { format_iso8601(application_history.as_json) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_application_history_id', admin: true do
        let(:url) { "/api/v1/applications/#{application.id}/histories/0" }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
      end
    end

    describe 'POST /applications/:application_id/histories' do
      let(:method) { 'post' }
      let(:url) { "/api/v1/applications/#{application.id}/histories" }
      let(:params) { FactoryGirl.attributes_for(:application_history, application_id: application.id) }
      let(:result) do
        params.merge(
          id: Fixnum,
          created_at: String,
          updated_at: String,
          version: Date.today.strftime('%Y%m%d') + '-002'
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('201 Created')
        it_behaves_like('create audit with project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Created')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Created')
      end
    end

    describe 'PUT /applications/:application_id/histories/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/applications/#{application.id}/histories/#{application_history.id}" }
      let(:params) do
        {
          'type' => 'dynamic',
          'url' => 'http://example.com/new_app.tar.gz',
          'protocol' => 'http',
          'revision' => 'develop',
          'pre_deploy' => 'some command to run pre deploy',
          'post_deploy' => 'some command to run post deploy',
          'parameters' => { 'some_key' => 'some_value' }.to_json
        }
      end
      let(:result) do
        application_history.as_json.merge(params).merge(
          'created_at' => application_history.created_at.iso8601(3),
          'updated_at' => String
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_application_history_id', admin: true do
        let(:url) { "/api/v1/applications/#{application.id}/histories/0" }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
        it_behaves_like('create audit with project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
      end
    end

    describe 'DELETE /applications/:application_id/histories/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/applications/#{application.id}/histories/#{application_history.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_application_history_id', admin: true do
        let(:url) { "/api/v1/applications/#{application.id}/histories/0" }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('204 No Content')
        it_behaves_like('create audit with project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('204 No Content')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('204 No Content')
      end
    end
  end
end
