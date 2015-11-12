describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'BlueprintHistoryAPI' do
    before do
      blueprint_history
      blueprint_history.pattern_snapshots << pattern_snapshot
    end

    describe 'GET /blueprints/:blueprint_id/histories' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/histories" }
      let(:result) { format_iso8601([blueprint_history]) }

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

    describe 'GET /blueprints/:blueprint_id/histories/:ver/parameters' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/histories/#{blueprint_history.version}/parameters" }
      let(:result) do
        result = {}
        result[blueprint_history.pattern_snapshots.first.name] = {}
        result
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/histories/0/parameters" }
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

    describe 'GET /blueprints/:blueprint_id/histories/:ver' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/histories/#{blueprint_history.version}" }
      let(:result) { format_iso8601(blueprint_history.as_json(methods: [:status, :pattern_snapshots])) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/histories/0" }
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

    describe 'DELETE /blueprints/:blueprint_id/histories/:ver' do
      before do
        Image.skip_callback :destroy, :before, :destroy_image
      end
      after do
        Image.set_callback :destroy, :before, :destroy_image, if: -> { status == :CREATE_COMPLETE }
      end

      let(:method) { 'delete' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/histories/#{blueprint_history.version}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/histories/0" }
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
