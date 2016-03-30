describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'AccountAPI' do
    let(:account) { FactoryGirl.create(:account) }
    let(:project_account) { FactoryGirl.create(:account, assign_project: project) }
    let(:monitoring_account) { project.accounts.where(email: "monitoring@#{project.name}.example.com").first }

    describe 'GET /accounts' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/accounts' }
      let!(:accounts) { [normal_account, admin_account, project_owner_account, project_operator_account, monitoring_account] }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'all (without project_id)' do
        let(:result) { format_iso8601(accounts) }

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

      context 'with project' do
        context 'in the existing project_id' do
          let(:params) { { project_id: project.id } }
          let(:result) { format_iso8601([project_owner_account, project_operator_account, monitoring_account]) }

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

        context 'in the not existing project_id' do
          let(:params) { { project_id: 9999 } }
          let(:result) { [] }

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

    describe 'GET /accounts/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/accounts/#{account.id}" }
      let(:result) { format_iso8601(account) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('200 OK')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/accounts/0' }
        it_behaves_like('404 Not Found')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        context 'for_other_project_user' do
          it_behaves_like('200 OK')
        end

        context 'for_same_project_user' do
          let(:url) { "/api/v1/accounts/#{project_account.id}" }
          let(:result) { format_iso8601(project_account) }
          it_behaves_like('200 OK')
        end
      end

      context 'project_operator', project_operator: true do
        context 'for_other_project_user' do
          it_behaves_like('200 OK')
        end

        context 'for_same_project_user' do
          let(:url) { "/api/v1/accounts/#{project_account.id}" }
          let(:result) { format_iso8601(project_account) }
          it_behaves_like('200 OK')
        end
      end
    end

    describe 'POST /accounts' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/accounts' }
      let(:params) { FactoryGirl.attributes_for(:account, admin: 0) }
      let(:result) do
        params.except(:password, :password_confirmation).merge(
          id: Fixnum,
          created_at: String,
          updated_at: String,
          admin: false
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'create normal account' do
        context 'normal_account', normal: true do
          it_behaves_like('403 Forbidden')
        end

        context 'administrator', admin: true do
          it_behaves_like('201 Created')
          it_behaves_like('create audit without project_id')
        end

        context 'project_owner', project_owner: true do
          it_behaves_like('403 Forbidden')
        end

        context 'project_operator', project_operator: true do
          it_behaves_like('403 Forbidden')
        end
      end

      context 'create admin account' do
        let(:params) { FactoryGirl.attributes_for(:account, admin: 1) }
        let(:result) do
          params.except(:password, :password_confirmation).merge(
            id: Fixnum,
            created_at: String,
            updated_at: String,
            admin: true
          )
        end

        context 'normal_account', normal: true do
          it_behaves_like('403 Forbidden')
        end

        context 'administrator', admin: true do
          it_behaves_like('201 Created')
          it_behaves_like('create audit without project_id')
        end

        context 'project_owner', project_owner: true do
          it_behaves_like('403 Forbidden')
        end

        context 'project_operator', project_operator: true do
          it_behaves_like('403 Forbidden')
        end
      end
    end

    describe 'PUT /accounts/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/accounts/#{account.id}" }
      let(:params) do
        {
          'email' => 'new@example.com',
          'name' => 'new_name',
          'password' => 'new_password',
          'password_confirmation' => 'new_password',
          'admin' => 0
        }
      end
      let(:result) do
        account.as_json.merge(params.except('password', 'password_confirmation')).merge(
          'created_at' => account.created_at.iso8601(3),
          'updated_at' => String,
          'admin' => false
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/accounts/0' }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
        it_behaves_like('create audit without project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('403 Forbidden')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('403 Forbidden')
      end
    end

    describe 'DELETE /accounts/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/accounts/#{account.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/accounts/0' }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('204 No Content')
        it_behaves_like('create audit without project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('403 Forbidden')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('403 Forbidden')
      end
    end
  end
end
