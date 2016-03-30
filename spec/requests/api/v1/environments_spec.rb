describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'EnvironmentAPI' do
    before do
      allow(Thread).to receive(:new)
      environment
    end

    describe 'GET /environments' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/environments' }
      let(:result) { format_iso8601([environment]) }

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

      context 'with system' do
        let(:params) { { system_id: application.system.id } }
        let(:result) { format_iso8601([environment]) }

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

        context 'in not exists system_id' do
          let(:params) { { system_id: 9999 } }
          let(:result) { [] }

          context 'not_logged_in' do
            it_behaves_like('401 Unauthorized')
          end

          context 'normal_account', normal: true do
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

      context 'with project' do
        let(:params) { { project_id: application.project.id } }
        let(:result) { format_iso8601([environment]) }

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

        context 'in not exists project_id' do
          let(:params) { { project_id: 9999 } }
          let(:result) { [] }

          context 'not_logged_in' do
            it_behaves_like('401 Unauthorized')
          end

          context 'normal_account', normal: true do
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
    end

    describe 'GET /environments/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/environments/#{environment.id}" }
      let(:result) { format_iso8601(environment) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/environments/0' }
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

    describe 'POST /environments' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/environments' }
      let(:params) do
        FactoryGirl.attributes_for(:environment,
                                   system_id: system.id,
                                   blueprint_id: blueprint_history.blueprint_id,
                                   version: blueprint_history.version,
                                   candidates_attributes: [{
                                     cloud_id: cloud.id,
                                     priority: 10
                                   }],
                                   stacks_attributes: [{
                                     name: 'test',
                                     template_parameters: '{}',
                                     parameters: '{}'
                                   }]
                                  )
      end
      let(:result) do
        params.except(:candidates_attributes, :stacks_attributes, :platform_outputs, :blueprint_id, :version, :blueprint_history).merge(
          id: Fixnum,
          blueprint_history_id: Fixnum,
          created_at: String,
          updated_at: String,
          status: 'PENDING',
          application_status: 'NOT_DEPLOYED',
          frontend_address: nil,
          consul_addresses: nil,
          template_parameters: String
        )
      end

      before do
        allow_any_instance_of(Environment).to receive(:create_stacks).and_return(true)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('202 Accepted')
        it_behaves_like('create audit with project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('202 Accepted')
        it_behaves_like('create audit with project_id')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('202 Accepted')
        it_behaves_like('create audit with project_id')
      end

      context 'in not existing system_id' do
        let(:params) do
          FactoryGirl.attributes_for(:environment,
                                     system_id: 9999,
                                     blueprint_id: blueprint_history.blueprint_id,
                                     version: blueprint_history.version,
                                     candidates_attributes: [{
                                       cloud_id: cloud.id,
                                       priority: 10
                                     }],
                                     stacks_attributes: [{
                                       name: 'test',
                                       template_parameters: '{}',
                                       parameters: '{}'
                                     }]
                                    )
        end

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

      context 'in not existing blueprint_id' do
        let(:params) do
          FactoryGirl.attributes_for(:environment,
                                     system_id: system.id,
                                     blueprint_id: 9999,
                                     version: blueprint_history.version,
                                     candidates_attributes: [{
                                       cloud_id: cloud.id,
                                       priority: 10
                                     }],
                                     stacks_attributes: [{
                                       name: 'test',
                                       template_parameters: '{}',
                                       parameters: '{}'
                                     }]
                                    )
        end

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

      context 'in not existing cloud_id' do
        let(:params) do
          FactoryGirl.attributes_for(:environment,
                                     system_id: system.id,
                                     blueprint_id: blueprint_history.blueprint_id,
                                     version: blueprint_history.version,
                                     candidates_attributes: [{
                                       cloud_id: 9999,
                                       priority: 10
                                     }],
                                     stacks_attributes: [{
                                       name: 'test',
                                       template_parameters: '{}',
                                       parameters: '{}'
                                     }]
                                    )
        end

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

    describe 'PUT /environments/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/environments/#{environment.id}" }
      let(:params) do
        {
          'name' => 'new_name',
          'description' => 'new_description'
        }
      end
      let(:result) do
        environment.as_json.merge(params).merge(
          'created_at' => environment.created_at.iso8601(3),
          'updated_at' => String
        )
      end

      before do
        allow_any_instance_of(Environment).to receive(:create_stacks).and_return(true)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/environments/0' }
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

    describe 'DELETE /environments/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/environments/#{new_environment.id}" }
      let(:new_environment) { FactoryGirl.create(:environment, system: system, blueprint_history: blueprint_history, candidates_attributes: [{ cloud_id: cloud.id, priority: 10 }]) }

      before do
        allow_any_instance_of(Environment).to receive(:destroy_stacks).and_return(true)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/environments/0' }
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

    describe 'POST /environments/:id/rebuild' do
      let(:method) { 'post' }
      let(:url) { "/api/v1/environments/#{environment.id}/rebuild" }
      let(:params) do
        {
          'blueprint_id' => blueprint_history.blueprint.id,
          'version' => blueprint_history.version,
          'description' => 'new_description',
          'switch' => true
        }
      end
      let(:result) do
        environment.as_json.merge(params.except('switch', 'blueprint_id', 'version')).merge(
          'id' => Fixnum,
          'created_at' => String,
          'updated_at' => String,
          'name' => /#{environment.name}-*/,
          'frontend_address' => nil,
          'consul_addresses' => nil
        )
      end

      before do
        allow_any_instance_of(Environment).to receive(:create_stacks).and_return(true)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/environments/0/rebuild' }
        it_behaves_like('404 Not Found')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('202 Accepted')
        it_behaves_like('create audit with project_id')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('202 Accepted')
        it_behaves_like('create audit with project_id')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('202 Accepted')
        it_behaves_like('create audit with project_id')
      end
    end
  end
end
