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

        desc 'Show application version'
        params do
          requires :id, type: Integer, desc: 'Application id'
          requires :version, type: Integer, desc: 'Application version'
        end
        get '/:id/:version' do
          application_history = ::ApplicationHistory.find_by!(application_id: params[:id], version: params[:version])
          authorize!(:read, application_history)
          application_history
        end

        desc 'Create application'
        params do
          requires :system_id, type: Integer, desc: 'Target system id'
          requires :name, type: String, desc: 'Application name'
          requires :domain, type: String, desc: 'Domain name to point this application'
          requires :url, type: String, desc: "Application's git repository or tar.gz url"
          optional :type, type: String, default: 'dynamic', desc: 'Application type (dynamic or static)'
          optional :protocol, type: String, default: 'git', desc: 'Application file transferred protocol'
          optional :revision, type: String, default: 'master', desc: "Application's git repository revision"
          optional :pre_deploy, type: String, desc: 'Shellscript to run before deploy'
          optional :post_deploy, type: String, desc: 'Shellscript to run after deploy'
          optional :parameters, type: String, desc: 'JSON string to apply additional configuration'
        end
        post '/' do
          authorize!(:create, ::Application)
          body ::Application.create!(application_parameters)
          status 201
        end

        desc 'Update application'
        params do
          requires :id, type: Integer, desc: 'Application id'
          optional :name, type: String, desc: 'Application name'
          optional :domain, type: String, desc: 'Domain name to point this application'
          optional :url, type: String, desc: "Application's git repository or tar.gz url"
          optional :type, type: String, default: 'dynamic', desc: 'Application type (dynamic or static)'
          optional :protocol, type: String, default: 'git', desc: 'Application file transferred protocol'
          optional :revision, type: String, default: 'master', desc: "Application's git repository revision"
          optional :pre_deploy, type: String, desc: 'Shellscript to run before deploy'
          optional :post_deploy, type: String, desc: 'Shellscript to run after deploy'
          optional :parameters, type: String, desc: 'JSON string to apply additional configuration'
        end
        put '/:id' do
          application = ::Application.find(params[:id])
          authorize!(:update, application)
          application.update_attributes!(application_parameters)
          body application
          status 201
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

      helpers do
        def application_parameters
          declared(params.slice(:system_id, :name), include_missing: false).merge(
            histories_attributes: [
              declared(
                params.slice(
                  :domain,
                  :url,
                  :type,
                  :protocol,
                  :revision,
                  :pre_deploy,
                  :post_deploy,
                  :parameters
                ),
                include_missing: false
              )
            ]
          )
        end
      end
    end
  end
end
