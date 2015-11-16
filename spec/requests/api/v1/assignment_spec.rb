describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'AssignmentAPI' do
    let(:account) { FactoryGirl.create(:account) }
    let(:role) { project.roles.find_by(name: 'operator') }
    let(:assignment) { FactoryGirl.create(:assignment, project_id: project.id, account_id: account.id, roles: [role]) }
    before do
      assignment
    end

    describe 'GET /assignments' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/assignments' }
      let(:params) do
        {
          project_id: project.id
        }
      end
      let(:result) do
        format_iso8601(project.assignments)
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

    describe 'GET /assignments/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/assignments/#{assignment.id}" }
      let(:result) do
        format_iso8601(assignment)
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

    describe 'POST /assignments' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/assignments' }
      let(:new_account) { FactoryGirl.create(:account) }
      let(:params) { FactoryGirl.attributes_for(:assignment, project_id: project.id, account_id: new_account.id, roles: [role]) }
      let(:result) do
        params.except(:roles).merge(
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

    describe 'DELETE /assignments/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/assignments/#{new_assignment.id}" }
      let(:new_account) { FactoryGirl.create(:account) }
      let(:new_assignment) { FactoryGirl.create(:assignment, project_id: project.id, account_id: new_account.id, roles: [role]) }

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
