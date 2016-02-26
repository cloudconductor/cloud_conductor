describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'BlueprintHistoryAPI' do
    before do
      blueprint_history
      blueprint_history.pattern_snapshots << pattern_snapshot
      pattern_snapshot.parameters = <<-EOS
        {
          "cloud_formation": {
            "WebInstanceType" : {
              "Description" : "WebServer instance type",
              "Type" : "String"
            }
          },
          "terraform": {
            "aws": {
              "web_instance_type" : {
                "description" : "WebServer instance type",
                "default" : "t2.small"
              }
            },
            "openstack": {
              "ap_instance_type" : {
                "description" : "APServer instance type",
                "default" : "t2.small"
              }
            }
          }
        }
      EOS
      pattern_snapshot.providers = '{"aws":["cloud_formation","terraform"],"openstack":["cloud_formation","terraform"]}'
      pattern_snapshot.save!

      allow(CloudConductor::Config.system_build).to receive(:providers).and_return([:terraform, :cloud_formation])
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
        result[blueprint_history.pattern_snapshots.first.name] = {
          terraform: {
            aws: {
              web_instance_type: {
                description: 'WebServer instance type',
                default: 't2.small'
              }
            },
            openstack: {
              ap_instance_type: {
                description: 'APServer instance type',
                default: 't2.small'
              }
            }
          }
        }
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

      context 'filter by providers and clouds', project_operator: true do
        let(:params) do
          { 'cloud_ids' => cloud.id.to_s }
        end
        let(:result) do
          result = {}
          result[blueprint_history.pattern_snapshots.first.name] = {
            terraform: {
              aws: {
                web_instance_type: {
                  description: 'WebServer instance type',
                  default: 't2.small'
                }
              }
            }
          }
          result
        end
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
