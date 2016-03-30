describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'BlueprintPatternAPI' do
    before { blueprint_pattern }

    describe 'GET /blueprints/:blueprint_id/patterns' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/patterns" }
      let(:result) { format_iso8601([blueprint_pattern]) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_blueprint_id', admin: true do
        let(:url) { '/api/v1/blueprints/0/patterns' }
        it_behaves_like('404 Not Found')
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

    describe 'GET /blueprints/:blueprint_id/patterns/:pattern_id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/patterns/#{blueprint_pattern.pattern.id}" }
      let(:result) { format_iso8601(blueprint_pattern.as_json) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_blueprint_pattern_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/patterns/0" }
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

    describe 'POST /blueprints/:blueprint_id/patterns' do
      let(:method) { 'post' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/patterns" }
      let(:params) { FactoryGirl.attributes_for(:blueprint_pattern, blueprint_id: blueprint.id, pattern_id: pattern.id, platform_version: '6.5') }
      let(:result) do
        params.merge(
          id: Fixnum,
          created_at: String,
          updated_at: String,
          revision: String
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
        it_behaves_like('201 Created')
        it_behaves_like('create audit with project_id')
      end

      context 'in not existing pattern_id' do
        let(:params) { FactoryGirl.attributes_for(:blueprint_pattern, blueprint_id: blueprint.id, pattern_id: 9999) }

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
          it_behaves_like('400 BadRequest')
        end
      end
    end

    describe 'PUT /blueprints/:blueprint_id/patterns/:pattern_id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/patterns/#{blueprint_pattern.pattern.id}" }
      let(:params) do
        {
          'revision' => 'dummy',
          'platform' => 'centos',
          'platform_version' => 'dummy_version'
        }
      end
      let(:result) do
        blueprint_pattern.as_json.merge(params).merge(
          'created_at' => blueprint_pattern.created_at.iso8601(3),
          'updated_at' => String
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_blueprint_pattern_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/patterns/0" }
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

    describe 'DELETE /blueprints/:blueprint_id/patterns/:pattern_id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/patterns/#{blueprint_pattern.pattern.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_blueprint_pattern_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/patterns/0" }
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
