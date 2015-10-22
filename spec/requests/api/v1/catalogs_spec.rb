describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'CatalogAPI' do
    before { catalog }

    describe 'GET /blueprints/:blueprint_id/catalogs' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/catalogs" }
      let(:result) { format_iso8601([catalog]) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_blueprint_id', admin: true do
        let(:url) { '/api/v1/blueprints/0/catalogs' }
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

    describe 'GET /blueprints/:blueprint_id/catalogs/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/catalogs/#{catalog.id}" }
      let(:result) { format_iso8601(catalog.as_json) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_catalog_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/catalogs/0" }
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

    describe 'POST /blueprints/:blueprint_id/catalogs' do
      let(:method) { 'post' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/catalogs" }
      let(:params) { FactoryGirl.attributes_for(:catalog, blueprint_id: blueprint.id, pattern_id: pattern.id) }
      let(:result) do
        params.merge(
          id: Fixnum,
          created_at: String,
          updated_at: String,
          revision: String,
          os_version: String
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

    describe 'PUT /blueprints/:blueprint_id/catalogs/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/catalogs/#{catalog.id}" }
      let(:params) do
        {
          'revision' => 'dummy',
          'os_version' => 'dummy_os'
        }
      end
      let(:result) do
        catalog.as_json.merge(params).merge(
          'created_at' => catalog.created_at.iso8601(3),
          'updated_at' => String
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_catalog_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/catalogs/0" }
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

    describe 'DELETE /blueprints/:blueprint_id/catalogs/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/catalogs/#{catalog.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_catalog_id', admin: true do
        let(:url) { "/api/v1/blueprints/#{blueprint.id}/catalogs/0" }
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
