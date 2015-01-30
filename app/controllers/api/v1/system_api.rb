module API
  module V1
    class SystemAPI < API::V1::Base
      resource :systems do
        desc 'List systems'
        get '/' do
          authorize!(:read, ::System)
          ::System.all.select do |system|
            can?(:read, system)
          end
        end

        desc 'Show system'
        params do
          requires :id, type: Integer, desc: 'System id'
        end
        get '/:id' do
          system = ::System.find(params[:id])
          authorize!(:read, system)
          system
        end

        desc 'Create system'
        params do
          requires :project_id, type: Integer, desc: 'Project id'
          requires :name, type: String, desc: 'System name'
          requires :domain, type: String, desc: 'Domain name to designate this system'
          requires :clouds, type: Array, desc: 'Cloud ids to build system. First cloud is primary.'
          requires :stacks, type: Array, desc: 'Pattern parameters to build system'
        end
        post '/' do
          authorize!(:create, ::System)
          # TODO: need refactoring
          ActionController::Parameters.permit_all_parameters = true
          system_parameters = params.slice(:project_id, :name, :domain)
          system_parameters = ActionController::Parameters.new(system_parameters).permit(:project_id, :name, :domain)
          system = System.new(system_parameters)
          params[:clouds].each do |cloud|
            system.add_cloud(Cloud.find(cloud[:id]), cloud[:priority])
          end
          system.transaction do
            system.save!
            cloud = system.candidates.primary.cloud
            params[:stacks].each do |stack|
              attributes = ActionController::Parameters.new(stack.merge(cloud: cloud))
              system.stacks.create!(attributes)
            end
          end
          Thread.new do
            ActiveRecord::Base.establish_connection_pool.with_connection do
              CloudConductor::SystemBuilder.new(system).build
            end
          end
          status 201
          system
        end

        desc 'Update system'
        params do
          requires :id, type: Integer, desc: 'System id'
          optional :name, type: String, desc: 'System name'
          optional :domain, type: String, desc: 'Domain name to designate this system'
          optional :clouds, type: Array, desc: 'Cloud ids to build system. First cloud is primary.'
          optional :stacks, type: Array, desc: 'Pattern parameters to build system'
        end
        put '/:id' do
          system = ::System.find(params[:id])
          authorize!(:update, system)
          system.update_attributes!(declared_params)
          status 201
          system
        end

        desc 'Destroy system'
        params do
          requires :id, type: Integer, desc: 'System id'
        end
        delete '/:id' do
          system = ::System.find(params[:id])
          authorize!(:destroy, system)
          system.destroy
          status 204
        end
      end
    end
  end
end
