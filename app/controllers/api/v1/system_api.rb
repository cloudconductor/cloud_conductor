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
          optional :description, type: String, desc: 'System description'
        end
        post '/' do
          authorize!(:create, ::System)
          ::System.create!(declared_params)
        end

        desc 'Update system'
        params do
          requires :id, type: Integer, desc: 'System id'
          optional :name, type: String, desc: 'System name'
          optional :description, type: String, desc: 'System description'
        end
        put '/:id' do
          system = ::System.find(params[:id])
          authorize!(:update, system)
          system.update_attributes!(declared_params)
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
