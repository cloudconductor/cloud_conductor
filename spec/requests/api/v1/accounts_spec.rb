describe API do
  include ApiSpecHelper
  include_context 'api'
  include_context 'default_accounts'

  describe 'AccountAPI' do
    let(:account) { FactoryGirl.create(:account) }
    let(:project_account) do
      account = FactoryGirl.create(:account)
      FactoryGirl.create(:assignment, project: project, account: account)
      account
    end

    describe 'GET /accounts' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/accounts' }
      let(:accounts) { [normal_account, admin_account, project_owner_account, project_operator_account] }

      before do
        accounts
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        let(:result) { api_attributes([normal_account]) }
        it_behaves_like('200 OK')
      end

      context 'administrator', admin: true do
        let(:result) { api_attributes(accounts) }
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        let(:result) { api_attributes([project_owner_account, project_operator_account]) }
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        let(:result) { api_attributes([project_owner_account, project_operator_account]) }
        it_behaves_like('200 OK')
      end
    end

    describe 'GET /accounts/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/accounts/#{account.id}" }
      let(:result) { api_attributes(account) }

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
        context 'for_other_project_user' do
          it_behaves_like('403 Forbidden')
        end

        context 'for_same_project_user' do
          let(:url) { "/api/v1/accounts/#{project_account.id}" }
          let(:result) { api_attributes(project_account) }
          it_behaves_like('200 OK')
        end
      end

      context 'project_operator', project_operator: true do
        context 'for_other_project_user' do
          it_behaves_like('403 Forbidden')
        end

        context 'for_same_project_user' do
          let(:url) { "/api/v1/accounts/#{project_account.id}" }
          let(:result) { api_attributes(project_account) }
          it_behaves_like('200 OK')
        end
      end
    end

    describe 'POST /accounts' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/accounts' }
      let(:new_account) { FactoryGirl.attributes_for(:account, admin: 0) }
      let(:params) { new_account }
      let(:result) do
        new_account.except(:password, :password_confirmation).merge(
          id: Fixnum,
          created_at: String,
          updated_at: String,
          admin: false
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
        it_behaves_like('403 Forbidden')
      end
    end

    describe 'PUT /accounts/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/accounts/#{account.id}" }
      let(:update_account) do
        FactoryGirl.attributes_for(:account,
                                   admin: 0,
                                   password: 'new_password',
                                   password_confirmation: 'new_password')
      end
      let(:params) { update_account }
      let(:result) do
        update_account.except(:password, :password_confirmation).merge(
          id: account.id,
          created_at: String,
          updated_at: String,
          admin: false
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

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('204 No Content')
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
