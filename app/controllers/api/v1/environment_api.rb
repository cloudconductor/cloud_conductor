module API
  module V1
    class EnvironmentAPI < API::V1::Base # rubocop:disable ClassLength
      resource :environments do
        before do
          project = current_project(Environment)
          @project_id = nil
          @project_id = project.id if project
        end

        after do
          track_api(@project_id)
        end

        desc 'List environments'
        params do
          optional :system_id, type: Integer, desc: 'System id'
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/' do
          if params[:system_id]
            environments = ::Environment.where(system_id: params[:system_id])
          elsif params[:project_id]
            environments = ::Environment.select_by_project_id(params[:project_id])
          else
            environments = ::Environment.all
          end

          environments.select do |environment|
            can?(:read, environment)
          end
        end

        desc 'Show environment'
        params do
          requires :id, type: Integer, desc: 'Environment id'
        end
        get '/:id' do
          environment = ::Environment.find(params[:id])
          authorize!(:read, environment)
          environment
        end

        desc 'Create environment'
        params do
          requires :system_id, type: Integer, exists_id: :system, desc: 'System id'
          requires :blueprint_id, type: Integer, exists_id: :blueprint, desc: 'Blueprint id'
          requires :version, type: Integer, desc: 'Blueprint version'
          requires :name, type: String, desc: 'Environment name'
          optional :description, type: String, desc: 'Environment description'
          optional :template_parameters, type: String, desc: 'Variables to build environment by cfn/terraform'
          optional :user_attributes, type: String, desc: 'User Attribute JSON'
          requires :candidates_attributes, type: Array, desc: 'Cloud ids to build environment' do
            requires :cloud_id, type: String, desc: 'Cloud id'
            optional :priority, type: Integer, desc: 'Cloud priority(prefer cloud that has higher value)'
          end
        end
        post '/' do
          system = ::System.find_by(id: params[:system_id])
          authorize!(:read, system)
          authorize!(:create, ::Environment, project: system.project)
          version = params[:version] || Blueprint.find(params[:blueprint_id]).histories.last.version
          blueprint_history = BlueprintHistory.where(blueprint_id: params[:blueprint_id], version: version).first!
          authorize!(:read, blueprint_history)

          attributes = declared_params.except(:blueprint_id, :version).merge(blueprint_history_id: blueprint_history.id)
          environment = Environment.create!(attributes)

          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              environment.build_infrastructure

              if system.primary_environment.nil? && environment.status == :CREATE_COMPLETE
                system.update_attributes!(primary_environment: environment)
              end
            end
          end

          status 202
          environment
        end

        desc 'Update environment'
        params do
          requires :id, type: Integer, desc: 'Environment id'
          optional :name, type: String, desc: 'Environment name'
          optional :description, type: String, desc: 'Environment description'
          optional :user_attributes, type: String, desc: 'User Attributes JSON'
          optional :template_parameters, type: String, desc: 'Variables to build environment by cfn/terraform'
        end
        put '/:id' do
          environment = ::Environment.find(params[:id])
          authorize!(:update, environment)

          environment.update_attributes!(declared_params.except(:id, :switch).merge(status: :PENDING))

          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              environment.update_infrastructure
            end
          end

          environment
        end

        desc 'Rebuild environment'
        params do
          requires :id, type: Integer, desc: 'Environment id'
          optional :name, type: String, desc: 'Blueprint name'
          optional :blueprint_id, type: Integer, desc: 'Blueprint id'
          optional :version, type: Integer, desc: 'Blueprint version'
          optional :description, type: String, desc: 'Environment description'
          optional :switch, type: Boolean, desc: 'Switch primary environment automatically'
          optional :template_parameters, type: String, desc: 'Variables to build environment by cfn/terraform'
          optional :user_attributes, type: String, desc: 'User Attributes JSON'
        end
        post '/:id/rebuild' do
          environment = ::Environment.find(params[:id])
          authorize!(:read, environment)
          authorize!(:create, ::Environment, project: environment.project)

          attributes = declared_params.except(:blueprint_id, :version, :id, :switch)
          if params[:blueprint_id]
            version = params[:version] || Blueprint.find(params[:blueprint_id]).histories.last.version
            blueprint_history = BlueprintHistory.where(blueprint_id: params[:blueprint_id], version: version).first!
            authorize!(:read, blueprint_history)

            attributes = attributes.merge(blueprint_history_id: blueprint_history.id)
          end

          new_environment = environment.dup
          new_environment.update_attributes!(attributes)

          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              new_environment.build_infrastructure

              if declared_params[:switch] && new_environment.status == :CREATE_COMPLETE
                new_environment.system.update_attributes!(primary_environment: new_environment)
              end
            end
          end

          status 202
          new_environment
        end

        desc 'Destroy environment'
        params do
          requires :id, type: Integer, desc: 'Environment id'
        end
        delete '/:id' do
          environment = ::Environment.find(params[:id])
          authorize!(:destroy, environment)
          environment.destroy
          status 204
        end
      end
    end
  end
end
