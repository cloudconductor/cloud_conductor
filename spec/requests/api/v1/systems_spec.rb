describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'SystemAPI' do
    before { system }

    describe 'GET /systems' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/systems' }
      let(:result) { format_iso8601([system]) }

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
      let(:result) { format_iso8601(system) }

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
      let(:params) { FactoryGirl.attributes_for(:system, project_id: project.id) }
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
        it_behaves_like('201 Created')
      end
    end

    describe 'PUT /systems/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/systems/#{system.id}" }
      let(:params) do
        {
          'name' => 'new_name',
          'domain' => 'new.example.com'
        }
      end
      let(:result) do
        system.as_json.merge(params).merge(
          'created_at' => system.created_at.iso8601(3),
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

    describe 'DELETE /systems/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/systems/#{new_system.id}" }
      let(:new_system) { FactoryGirl.create(:system, project: project) }

      before do
        allow_any_instance_of(Environment).to receive(:destroy_stacks).and_return(true)
      end

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

    describe 'PUT /systems/:id/switch' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/systems/#{system.id}/switch" }
      let(:blueprint) { FactoryGirl.create(:blueprint, project_id: project.id) }
      let(:new_environment) { FactoryGirl.create(:environment, system_id: system.id, blueprint_id: blueprint.id, candidates_attributes: [{ cloud_id: cloud.id, priority: 10 }]) }
      let(:params) { { environment_id: new_environment.id } }
      let(:result) do
        system.as_json.merge(
          'created_at' => system.created_at.iso8601(3),
          'updated_at' => String,
          'primary_environment_id' => new_environment.id
        )
      end

      before do
        allow_any_instance_of(System).to receive(:update_dns).and_return(true)
        allow_any_instance_of(System).to receive(:enable_monitoring).and_return(true)
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
  end
end
