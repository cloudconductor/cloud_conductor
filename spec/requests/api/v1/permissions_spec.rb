describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'PermissionAPI' do
    let(:project_admin_role) { project.roles.find_by(name: 'administrator') }
    let(:project_operator_role) { project.roles.find_by(name: 'operator') }
    let(:project_role) { role }
    let(:permission) { FactoryGirl.create(:permission, role: role) }

    before do
      permission
    end

    describe 'GET /roles/:role_id/permissions/' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/roles/#{role.id}/permissions" }
      let(:result) do
        format_iso8601([permission])
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        let(:result) { [] }
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

    describe 'GET /roles/:role_id/permissions/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/roles/#{role.id}/permissions/#{permission.id}" }
      let(:result) { format_iso8601(permission) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/roles/0' }
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

    describe 'POST /roles/:role_id/permissions/' do
      let(:method) { 'post' }
      let(:url) { "/api/v1/roles/#{role.id}/permissions" }
      let(:params) { FactoryGirl.attributes_for(:permission, role_id: role.id) }
      let(:result) do
        params.merge(
          'id' => Fixnum,
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
        it_behaves_like('201 Created')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Created')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('403 Forbidden')
      end
    end

    describe 'DELETE /roles/:roleid/permissions/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/roles/#{new_role.id}/permissions/#{new_permission.id}" }
      let(:new_role) { FactoryGirl.create(:role, project: project) }
      let(:new_permission) { FactoryGirl.create(:permission, role: new_role) }

      before do
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/roles/0' }
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
        it_behaves_like('403 Forbidden')
      end
    end
  end
end
