module API
  module V1
    class ApplicationHistoryAPI < API::V1::Base
      resource :applications do
        route_param :application_id do
          resource :histories do
            before do
              @project_id = nil
              if request.params.key?(:project_id)
                @project_id = request.params[:project_id]
              end

              if request.params.key?(:application_id)
                application = Application.find_by_id(request.params[:application_id])
                system_id = application.system_id if application
                system = System.find_by_id(system_id)
                @project_id = system.project_id if system
              end
            end

            after do
              track_api(@project_id)
            end

            desc 'List application histories'
            get '/' do
              Application.find(params[:application_id]).histories.select do |history|
                can?(:read, history)
              end
            end

            desc 'Show application history'
            params do
              requires :id, type: Integer, desc: 'Application history id'
            end
            get '/:id' do
              application = ::Application.find(params[:application_id])
              authorize!(:read, application)
              history = ::ApplicationHistory.find(params[:id])
              authorize!(:read, history)
              history
            end

            desc 'Create application history'
            params do
              requires :application_id, type: Integer, desc: 'Target application id'
              requires :url, type: String, desc: "Application's git repository or tar.gz url"
              optional :type, type: String, default: 'dynamic', desc: 'Application type (dynamic or static)'
              optional :protocol, type: String, default: 'git', desc: 'Application file transferred protocol'
              optional :revision, type: String, default: 'master', desc: "Application's git repository revision"
              optional :pre_deploy, type: String, desc: 'Shellscript to run before deploy'
              optional :post_deploy, type: String, desc: 'Shellscript to run after deploy'
              optional :parameters, type: String, default: '{}', desc: 'JSON string to apply additional configuration'
            end
            post '/' do
              application = ::Application.find(params[:application_id])
              authorize!(:update, application)
              authorize!(:create, ::ApplicationHistory, project: application.project)
              ::ApplicationHistory.create!(declared_params)
            end

            desc 'Update application history'
            params do
              requires :id, type: Integer, desc: 'Application history id'
              optional :url, type: String, desc: "Application's git repository or tar.gz url"
              optional :type, type: String, desc: 'Application type (dynamic or static)'
              optional :protocol, type: String, desc: 'Application file transferred protocol'
              optional :revision, type: String, desc: "Application's git repository revision"
              optional :pre_deploy, type: String, desc: 'Shellscript to run before deploy'
              optional :post_deploy, type: String, desc: 'Shellscript to run after deploy'
              optional :parameters, type: String, desc: 'JSON string to apply additional configuration'
            end
            put '/:id' do
              application = ::Application.find(params[:application_id])
              authorize!(:update, application)
              history = ::ApplicationHistory.find(params[:id])
              authorize!(:update, history)
              history.update_attributes!(declared_params)
              history
            end

            desc 'Destroy application history'
            params do
              requires :id, type: Integer, desc: 'Application history id'
            end
            delete '/:id' do
              application = ::Application.find(params[:application_id])
              authorize!(:update, application)
              history = ::ApplicationHistory.find(params[:id])
              authorize!(:destroy, history)
              history.destroy
              status 204
            end
          end
        end
      end
    end
  end
end
