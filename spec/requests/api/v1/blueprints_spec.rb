describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'BlueprintAPI' do
    before do
      blueprint
    end

    describe 'GET /blueprints' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/blueprints' }
      let(:result) { format_iso8601([blueprint]) }

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

    describe 'GET /blueprints with project_id' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/blueprints' }
      let(:params) { { project_id: blueprint.project.id } }
      let(:result) { format_iso8601([blueprint]) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        let(:result) { [] }
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
      let(:params) { FactoryGirl.attributes_for(:blueprint, project_id: project.id) }
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

      context 'in not existing project_id' do
        let(:params) { FactoryGirl.attributes_for(:blueprint, project_id: 9999) }

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

    describe 'PUT /blueprints/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}" }
      let(:params) do
        {
          'name' => 'new_name',
          'description' => 'new_description'
        }
      end
      let(:result) do
        blueprint.as_json.merge(params).merge(
          'created_at' => blueprint.created_at.iso8601(3),
          'updated_at' => String
        )
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
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
      end
    end

    describe 'DELETE /blueprints/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}" }

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

    describe 'POST /blueprints/:id/build' do
      let(:method) { 'post' }
      let(:url) { "/api/v1/blueprints/#{blueprint.id}/build" }
      let(:result) do
        params.merge(
          'id' => Fixnum,
          'version' => Fixnum,
          'blueprint_id' => Fixnum,
          'consul_secret_key' => String,
          'status' => String,
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
        it_behaves_like('202 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('202 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('202 Accepted')
      end
    end
  end
end
