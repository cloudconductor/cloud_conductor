module API
  module V1
    class ApplicationAPI < API::V1::Base
      resource :applications do
        desc 'List applications'
        params do
          requires :system_id, type: Integer, desc: 'System id'
        end
        get '/' do
          authorize!(:read, ::Application)
          ::Application.where(system_id: params[:system_id]).select do |application|
            can?(:read, application)
          end
        end

        desc 'Show application'
        params do
          requires :id, type: Integer, desc: 'Application id'
        end
        get '/:id' do
          application = ::Application.find(params[:id])
          authorize!(:read, application)
          application
        end

        desc 'Create application'
        params do
          requires :system_id, type: Integer, desc: 'Target system id'
          requires :name, type: String, desc: 'Application name'
        end
        post '/' do
          authorize!(:create, ::Application)
          ::Application.create!(declared_params)
        end

        desc 'Update application'
        params do
          requires :id, type: Integer, desc: 'Application id'
          optional :name, type: String, desc: 'Application name'
        end
        put '/:id' do
          application = ::Application.find(params[:id])
          authorize!(:update, application)
          application.update_attributes!(declared_params)
          application
        end

        desc 'Destroy application'
        params do
          requires :id, type: Integer, desc: 'Application id'
        end
        delete '/:id' do
          application = ::Application.find(params[:id])
          authorize!(:destroy, application)
          application.destroy
          status 204
        end
      end
    end
  end
end
