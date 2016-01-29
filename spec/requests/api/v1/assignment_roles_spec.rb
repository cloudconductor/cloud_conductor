describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'AssignmentRoleAPI' do
    let(:account) { FactoryGirl.create(:account) }
    let(:role) { project.roles.find_by(name: 'operator') }
    let(:assignment) { FactoryGirl.create(:assignment, project_id: project.id, account_id: account.id, roles: [role]) }

    before do
      assignment
    end

    describe 'Get /assignments/:assignment_id/roles' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/assignments/#{assignment.id}/roles" }
      let(:result) do
        format_iso8601(assignment.assignment_roles)
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

    describe 'GET /assignments/:assignment_id/roles/:id' do
      let(:method) { 'get' }
      let(:assignment_role) { assignment.assignment_roles.all.first }
      let(:url) { "/api/v1/assignments/#{assignment.id}/roles/#{assignment_role.id}" }
      let(:result) do
        format_iso8601(assignment_role)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/assignments/0' }
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

    describe 'POST /assignments/:assignment_id/roles/' do
      let(:method) { 'post' }
      let(:new_role) { FactoryGirl.create(:role, project_id: project.id) }
      let(:url) { "/api/v1/assignments/#{assignment.id}/roles/" }
      let(:params) { { role_id: new_role.id } }
      let(:result) do
        params.merge(
          'id' => Fixnum,
          'role_name' => String,
          'assignment_id' => assignment.id,
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
        it_behaves_like('create audit with project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Created')
        it_behaves_like('create audit with project_id')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('403 Forbidden')
      end

      context 'in not existing role_id' do
        let(:params) { { role_id: 9999 } }

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

      context 'with other project role' do
        let(:other_project) { FactoryGirl.create(:project) }
        let(:params) { { role_id: other_project.roles.first.id } }

        context 'not_logged_in' do
          it_behaves_like('401 Unauthorized')
        end

        context 'normal_account', normal: true do
          it_behaves_like('403 Forbidden')
        end

        context 'administrator', admin: true do
          it_behaves_like('400 BadRequest')
        end

        context 'project_owner', project_owner: true do
          it_behaves_like('400 BadRequest')
        end

        context 'project_operator', project_operator: true do
          it_behaves_like('403 Forbidden')
        end
      end
    end

    describe 'DELETE /assignments/:assignment_id/roles/:id' do
      let(:method) { 'delete' }
      let(:assignment_role) { assignment.assignment_roles.all.first }
      let(:url) { "/api/v1/assignments/#{assignment.id}/roles/#{assignment_role.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end
      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/systems/0' }
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
        it_behaves_like('create audit with project_id')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('403 Forbidden')
      end
    end
  end
end
