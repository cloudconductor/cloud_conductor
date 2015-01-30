describe API do
  include ApiSpecHelper
  include_context 'api'
  include_context 'default_accounts'

  describe 'SystemAPI' do
    let(:system) { FactoryGirl.create(:system, project_id: project.id) }
    before { system }

    describe 'GET /systems' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/systems' }
      let(:result) { [api_attributes(system)] }

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

    describe 'GET /systems/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/systems/#{system.id}" }
      let(:result) { api_attributes(system) }

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

    describe 'POST /systems' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/systems' }
      let(:new_system) { FactoryGirl.build(:system, project_id: project.id) }
      let(:params) do
        new_system.attributes.merge(
          clouds: [{
            id: FactoryGirl.create(:cloud_aws, project_id: project.id).id,
            priority: 10
          }],
          stacks: [{
            name: 'system-1-pattern-1',
            pattern_id: FactoryGirl.create(:pattern).id,
            template_parameters: {},
            parameters: {}
          }]
        )
      end
      let(:result) do
        new_system.attributes.merge(
          'id' => Fixnum,
          'created_at' => String,
          'updated_at' => String,
          'template_parameters' => '{}'
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Accepted')
      end
    end

    describe 'PUT /systems/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/systems/#{system.id}" }
      let(:new_system) { FactoryGirl.build(:system, project_id: project.id) }
      let(:params) { new_system.attributes }
      let(:result) do
        new_system.attributes.merge(
          'id' => system.id,
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
        it_behaves_like('201 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Accepted')
      end
    end

    describe 'DELETE /systems/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/systems/#{system.id}" }

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
