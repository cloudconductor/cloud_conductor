describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'CloudAPI' do
    before { cloud }

    describe 'GET /clouds' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/clouds' }
      let(:result) { format_iso8601([cloud]) }

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

    describe 'GET /clouds/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/clouds/#{cloud.id}" }
      let(:result) { format_iso8601(cloud) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/clouds/0' }
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

    describe 'POST /clouds' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/clouds' }
      let(:params) { FactoryGirl.attributes_for(:cloud, :openstack, project_id: project.id) }
      let(:result) do
        params.merge(
          id: Fixnum,
          secret: '********',
          created_at: String,
          updated_at: String
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
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Created')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Created')
      end
    end

    describe 'PUT /clouds/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/clouds/#{cloud.id}" }
      let(:params) do
        {
          'name' => 'new_openstack',
          'type' => 'openstack',
          'entry_point' => 'http://127.0.0.1:5000/v1',
          'tenant_name' => 'demo',
          'key' => 'new_key',
          'secret' => 'new_secret'
        }
      end
      let(:result) do
        cloud.as_json.merge(params).merge(
          'secret' => '********',
          'created_at' => cloud.created_at.iso8601(3),
          'updated_at' => String
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/clouds/0' }
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

    describe 'DELETE /clouds/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/clouds/#{new_cloud.id}" }
      let(:new_cloud) { FactoryGirl.create(:cloud, project_id: project.id) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/clouds/0' }
        it_behaves_like('404 Not Found')
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
