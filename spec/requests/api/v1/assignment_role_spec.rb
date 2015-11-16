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
