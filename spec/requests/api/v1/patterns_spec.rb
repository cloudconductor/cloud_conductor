describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'PatternAPI' do
    before do
      pattern
    end

    describe 'GET /patterns' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/patterns' }
      let(:result) { format_iso8601([pattern]) }

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

      context 'with project' do
        let(:params) { { project_id: project.id } }

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
      end
    end

    describe 'GET /patterns/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/patterns/#{pattern.id}" }
      let(:result) { format_iso8601(pattern) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/patterns/0' }
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

    describe 'POST /patterns' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/patterns' }
      let(:params) { FactoryGirl.attributes_for(:pattern, :platform, project_id: project.id) }
      let(:result) do
        params.except(:parameters).merge(
          'id' => Fixnum,
          'roles' => String,
          'secret_key' => '********',
          'providers' => nil,
          'created_at' => String,
          'updated_at' => String
        )
      end

      before do
        allow_any_instance_of(Pattern).to receive(:update_metadata) do |pattern|
          pattern.name = params[:name]
          pattern.type = params[:type]
          pattern.roles = %w(web ap db).to_json
        end
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
        it_behaves_like('201 Created')
        it_behaves_like('create audit with project_id')
      end

      context 'in not existing project_id' do
        let(:params) { FactoryGirl.attributes_for(:pattern, :platform, project_id: 9999) }

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

    describe 'PUT /patterns/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/patterns/#{pattern.id}" }
      let(:params) do
        {
          'url' => 'https://example.com/cloudconductor-dev/sample_optional_pattern.git',
          'revision' => 'develop'
        }
      end
      let(:result) do
        pattern.as_json.merge(params).merge(
          'created_at' => pattern.created_at.iso8601(3),
          'updated_at' => String
        )
      end

      before do
        allow_any_instance_of(Pattern).to receive(:update_metadata)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/patterns/0' }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
        it_behaves_like('create audit with project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
        it_behaves_like('create audit with project_id')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
        it_behaves_like('create audit with project_id')
      end
    end

    describe 'DELETE /patterns/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/patterns/#{pattern.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/patterns/0' }
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
        it_behaves_like('204 No Content')
        it_behaves_like('create audit with project_id')
      end
    end
  end
end
