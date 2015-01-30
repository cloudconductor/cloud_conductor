describe API do
  include ApiSpecHelper
  include_context 'api'
  include_context 'default_accounts'

  describe 'ApplicationAPI' do
    let(:system) { FactoryGirl.create(:system, project_id: project.id) }
    let(:application) { FactoryGirl.create(:application, system_id: system.id) }
    before { application }

    describe 'GET /applications' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/applications' }
      let(:result) { [api_attributes(application)] }
      let(:params) { { system_id: application.system.id } }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
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

    describe 'GET /applications/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/applications/#{application.id}" }
      let(:result) { api_attributes(application) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
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
      let(:application_parameters) { FactoryGirl.attributes_for(:application, system_id: system.id) }
      let(:application_history_parameters) { FactoryGirl.attributes_for(:application_history) }
      let(:params) { application_parameters.merge(application_history_parameters) }
      let(:result) do
        application_parameters.merge(
          id: Fixnum,
          created_at: String,
          updated_at: String,
          latest: application_history_parameters.merge(
            id: Fixnum,
            application_id: Fixnum,
            status: 'not_yet',
            version: String,
            created_at: String,
            updated_at: String
          ),
          latest_version: String
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Accepted')
      end
    end

    describe 'PUT /applications/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/applications/#{application.id}" }
      let(:application_parameters) { FactoryGirl.attributes_for(:application, system_id: system.id) }
      let(:application_history_parameters) { FactoryGirl.attributes_for(:application_history) }
      let(:params) { application_parameters.merge(application_history_parameters) }
      let(:result) do
        application_parameters.merge(
          id: Fixnum,
          created_at: String,
          updated_at: String,
          latest: application_history_parameters.merge(
            id: Fixnum,
            application_id: Fixnum,
            status: 'not_yet',
            version: String,
            created_at: String,
            updated_at: String
          ),
          latest_version: String
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Accepted')
      end
    end

    describe 'DELETE /applications/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/applications/#{application.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('204 No Content')
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
