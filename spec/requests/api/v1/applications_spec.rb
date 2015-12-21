describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'ApplicationAPI' do
    before { application }

    describe 'GET /applications' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/applications' }
      let(:result) { format_iso8601([application]) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
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

      context 'with system' do
        let(:params) { { system_id: application.system.id } }
        let(:result) { format_iso8601([application]) }

        context 'not_logged_in' do
          it_behaves_like('401 Unauthorized')
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

      context 'with project' do
        let(:params) { { project_id: application.project.id } }
        let(:result) { format_iso8601([application]) }

        context 'not_logged_in' do
          it_behaves_like('401 Unauthorized')
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
    end

    describe 'GET /applications/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/applications/#{application.id}" }
      let(:result) { format_iso8601(application) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/applications/0' }
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

    describe 'POST /applications' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/applications' }
      let(:params) { FactoryGirl.attributes_for(:application, system_id: system.id) }
      let(:result) do
        params.merge(
          'id' => Fixnum,
          'created_at' => String,
          'updated_at' => String,
          'domain' => 'app.example.com'
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

      context 'in not existing system_id' do
        let(:params) { FactoryGirl.attributes_for(:application, system_id: 9999) }

        context 'not_logged_in' do
          it_behaves_like('401 Unauthorized')
        end

        context 'normal_account', normal: true do
          it_behaves_like('400 BadRequest')
        end

        context 'administrator', admin: true do
          it_behaves_like('400 BadRequest')
        end

        context 'project_owner', project_owner: true do
          it_behaves_like('400 BadRequest')
        end

        context 'project_operator', project_operator: true do
          it_behaves_like('400 BadRequest')
        end
      end
    end

    describe 'PUT /applications/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/applications/#{application.id}" }
      let(:params) { { name: 'new_name' } }
      let(:result) do
        application.as_json.merge(
          'created_at' => application.created_at.iso8601(3),
          'updated_at' => String,
          'name' => 'new_name'
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/applications/0' }
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

    describe 'DELETE /applications/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/applications/#{application.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/applications/0' }
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

    describe 'POST /applications/:id/deploy' do
      let(:method) { 'post' }
      let(:url) { "/api/v1/applications/#{application.id}/deploy" }
      let(:params) do
        FactoryGirl.attributes_for(:deployment,
                                   environment_id: environment.id,
                                   application_history_id: application_history.id
                                  )
      end
      let(:result) do
        params.merge(
          'id' => Fixnum,
          'created_at' => String,
          'updated_at' => String,
          'status' => :PENDING
        )
      end

      before do
        environment.update_columns(status: :CREATE_COMPLETE)
        allow_any_instance_of(Deployment).to receive(:consul_request) do |deployment|
          deployment.status = :PENDING
        end
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/applications/0/deploy' }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('202 Accepted')
        it_behaves_like('create audit with project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('202 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('202 Accepted')
      end
    end
  end
end
