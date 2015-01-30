describe API do
  include ApiSpecHelper
  include_context 'api'
  include_context 'default_accounts'

  describe 'CloudAPI' do
    let(:cloud) { FactoryGirl.create(:cloud_aws, project_id: project.id) }
    before { cloud }

    describe 'GET /clouds' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/clouds' }
      let(:result) { [api_attributes(cloud)] }

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
      let(:result) { api_attributes(cloud) }

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

    describe 'POST /clouds' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/clouds' }
      let(:new_cloud) { FactoryGirl.build(:cloud_openstack, project_id: project.id) }
      let(:params) { new_cloud.attributes }
      let(:result) do
        new_cloud.attributes.merge(
          'id' => Fixnum,
          'secret' => '********',
          'created_at' => String,
          'updated_at' => String
        )
      end

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

    describe 'PUT /clouds/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/clouds/#{cloud.id}" }
      let(:new_cloud) { FactoryGirl.build(:cloud_openstack, project_id: project.id) }
      let(:params) { new_cloud.attributes }
      let(:result) do
        new_cloud.attributes.merge(
          'id' => cloud.id,
          'secret' => '********',
          'created_at' => String,
          'updated_at' => String
        )
      end

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

    describe 'DELETE /clouds/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/clouds/#{cloud.id}" }

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
