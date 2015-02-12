module API
  module V1
    class EnvironmentAPI < API::V1::Base
      resource :environments do
        desc 'List environments'
        get '/' do
          authorize!(:read, ::Environment)
          ::Environment.all.select do |environment|
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
          requires :system_id, type: Integer, desc: 'System id'
          requires :blueprint_id, type: Integer, desc: 'Blueprint id'
          requires :name, type: String, desc: 'Environment name'
          optional :description, type: String, desc: 'Environment description'
          requires :domain, type: String, desc: 'Domain name to designate this environment'
          requires :candidates_attributes, type: Array, desc: 'Cloud ids to build environment. First cloud is primary.' do
            requires :cloud_id, type: String, desc: 'Cloud id'
            optional :priority, type: Integer, desc: 'Cloud priority(prefer cloud that has higher value)'
          end
          optional :template_parameters, type: String, desc: 'Parameters for cloudformation', default: '{}'
        end
        post '/' do
          authorize!(:create, ::Environment)
          environment = Environment.create!(declared_params)

          Thread.new do
            CloudConductor::SystemBuilder.new(environment).build
          end

          environment
        end

        desc 'Update environment'
        params do
          requires :id, type: Integer, desc: 'Environment id'
          optional :name, type: String, desc: 'Environment name'
          optional :domain, type: String, desc: 'Domain name to designate this environment'
          optional :clouds, type: Array, desc: 'Cloud ids to build environment. First cloud is primary.'
          optional :stacks, type: Array, desc: 'Pattern parameters to build environment'
        end
        put '/:id' do
          environment = ::Environment.find(params[:id])
          authorize!(:update, environment)
          environment.update_attributes!(declared_params)
          environment
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
