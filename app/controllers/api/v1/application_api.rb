module API
  module V1
    class ApplicationAPI < API::V1::Base
      resource :applications do
        before do
          project = current_project(Application)
          @project_id = nil
          @project_id = project.id if project
        end

        after do
          track_api(@project_id)
        end

        desc 'List applications'
        params do
          optional :system_id, type: Integer, desc: 'Target system id'
          optional :project_id, type: Integer, desc: 'Target project id'
        end
        get '/' do
          if params[:system_id]
            applications = ::Application.where(system_id: params[:system_id])
          elsif params[:project_id]
            applications = ::Application.select_by_project_id(params[:project_id])
          else
            applications = ::Application.all
          end
          applications.select do |application|
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
          requires :system_id, type: Integer, exists_id: :system, desc: 'Target system id'
          requires :name, type: String, desc: 'Application name'
          optional :description, type: String, desc: 'Application description'
          optional :domain, type: String, desc: 'Application domain name'
        end
        post '/' do
          system = ::System.find_by(id: params[:system_id])
          authorize!(:read, system)
          authorize!(:create, ::Application, project: system.project)
          ::Application.create!(declared_params)
        end

        desc 'Update application'
        params do
          requires :id, type: Integer, desc: 'Application id'
          optional :name, type: String, desc: 'Application name'
          optional :description, type: String, desc: 'Application description'
          optional :domain, type: String, desc: 'Application domain name'
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

        desc 'Deploy application to environment'
        params do
          requires :id, type: Integer, desc: 'Application id'
          requires :environment_id, type: Integer, desc: 'Target environment id'
          optional :application_history_id, type: Integer, desc: 'Application history id'
        end
        post '/:id/deploy' do
          application = ::Application.find(params[:id])
          authorize!(:read, application)
          authorize!(:create, ::Deployment, project: application.project)
          if params[:application_history_id]
            application_history = application.histories.find(params[:application_history_id])
          else
            application_history = application.latest
          end
          authorize!(:read, application_history)
          params[:application_history_id] = application_history.id
          deployment = ::Deployment.create!(declared_params.except(:id))
          status 202
          deployment
        end
      end
    end
  end
end
