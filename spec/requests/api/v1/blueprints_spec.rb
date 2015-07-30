describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'BlueprintAPI' do
    before { blueprint }

    describe 'GET /blueprints' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/blueprints' }
      let(:result) { format_iso8601([blueprint]) }

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

    describe 'GET /blueprints/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}" }
      let(:result) { format_iso8601(blueprint) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/blueprints/0' }
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

    describe 'POST /blueprints' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/blueprints' }
      let(:consul_secret_key) { SecureRandom.base64(16) }
      let(:params) { FactoryGirl.attributes_for(:blueprint, project_id: project.id) }
      let(:result) do
        params.except(:patterns_attributes).merge(
          'id' => Fixnum,
          'created_at' => String,
          'updated_at' => String,
          'status' => 'CREATE_COMPLETE'
        )
      end

      before do
        mock_process_status = double('process_status')
        allow(mock_process_status).to receive(:success?).and_return(true)
        allow_any_instance_of(Blueprint).to receive(:systemu).with('consul keygen').and_return([mock_process_status, consul_secret_key, ''])
        allow_any_instance_of(Pattern).to receive(:execute_packer) do |pattern|
          pattern.images << FactoryGirl.build(:image, pattern: pattern, base_image: base_image, cloud: cloud)
        end
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('202 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('202 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('202 Accepted')
      end
    end

    describe 'PUT /blueprints/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}" }
      let(:params) do
        {
          'name' => 'new_name',
          'description' => 'new_description',
          'patterns_attributes' => blueprint.patterns.map(&:attributes).push('url' => 'http://example.com/new_pattern.git',
                                                                             'revision' => 'master')
        }
      end
      let(:result) do
        blueprint.as_json.merge(params.except('patterns_attributes')).merge(
          'created_at' => blueprint.created_at.iso8601(3),
          'updated_at' => String
        )
      end

      before do
        allow_any_instance_of(Pattern).to receive(:execute_packer).and_return(true)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/blueprints/0' }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('202 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('202 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('202 Accepted')
      end
    end

    describe 'DELETE /blueprints/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}" }

      before do
        allow_any_instance_of(Image).to receive(:destroy_image).and_return(true)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/blueprints/0' }
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
        it_behaves_like('204 No Content')
      end
    end
  end
end
