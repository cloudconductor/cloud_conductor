describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'RoleAPI' do
    let(:project_admin_role) { project.roles.find_by(name: 'administrator') }
    let(:project_operator_role) { project.roles.find_by(name: 'operator') }
    let(:project_role) { role }

    before do
      role
    end

    describe 'GET /roles' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/roles' }
      let(:other_project_owner) { FactoryGirl.create(:account) }
      let(:other_project) { FactoryGirl.create(:project, owner: other_project_owner) }
      let(:result) do
        format_iso8601([project_admin_role, project_operator_role, project_role])
      end

      before do
        other_project
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        let(:result) { [] }
        it_behaves_like('200 OK')
      end

      context 'administrator', admin: true do
        let(:result) do
          roles = project.roles.all + other_project.roles.all
          format_iso8601(roles)
        end
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
      end
    end

    describe 'GET /roles with project_id' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/roles' }
      let(:other_project_owner) { FactoryGirl.create(:account) }
      let(:other_project) { FactoryGirl.create(:project, owner: other_project_owner) }
      let(:params) do
        {
          'project_id' => project.id
        }
      end
      let(:result) do
        format_iso8601([project_admin_role, project_operator_role, project_role])
      end

      before do
        other_project
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

    describe 'GET /roles/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/roles/#{role.id}" }
      let(:result) { format_iso8601(role) }

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

    describe 'POST /roles' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/roles' }
      let(:params) { FactoryGirl.attributes_for(:role, project_id: project.id) }
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

    describe 'PUT /roles/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/roles/#{role.id}" }
      let(:params) do
        {
          'name' => 'new_name',
          'description' => 'new_description'
        }
      end
      let(:result) do
        role.as_json.merge(params).merge(
          'created_at' => role.created_at.iso8601(3),
          'updated_at' => String
        )
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
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('403 Forbidden')
      end
    end

    describe 'DELETE /roles/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/roles/#{new_role.id}" }
      let(:new_role) { FactoryGirl.create(:role, project: project) }

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
