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
      let(:result) { format_iso8601(::Assignment.all) }

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
        let(:result) { format_iso8601(project.assignments) }
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        let(:result) { format_iso8601(project.assignments) }
        it_behaves_like('200 OK')
      end

      context 'with project' do
        let(:params) { { project_id: project.id } }
        let(:result) { format_iso8601(project.assignments) }

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

        context 'in not existing project_id' do
          let(:params) { { project_id: 9999 } }
          let(:result) { [] }

          context 'not_logged_in' do
            it_behaves_like('401 Unauthorized')
          end

          context 'normal_account', normal: true do
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

      context 'with account' do
        let(:params) { { account_id: project_operator_account.id } }
        let(:result) { format_iso8601(Assignment.where(account_id: project_operator_account.id)) }

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

        context 'in not existing account_id' do
          let(:params) { { account_id: 9999 } }
          let(:result) { [] }
          context 'not_logged_in' do
            it_behaves_like('401 Unauthorized')
          end

          context 'normal_account', normal: true do
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

      context 'in not existing project_id' do
        let(:params) { { project_id: 9999, account_id: new_account.id } }

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

      context 'in not existing account_id' do
        let(:params) { { project_id: project.id, account_id: 9999 } }

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
