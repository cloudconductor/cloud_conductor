module API
  module V1
    class ApplicationHistoryAPI < API::V1::Base
      resource :application_histories do
        desc 'List application histories'
        params do
          requires :application_id, type: Integer, desc: 'Application id'
        end
        get '/' do
          authorize!(:read, ::ApplicationHistory)
          ::ApplicationHistory.where(application_id: params[:application_id]).select do |history|
            can?(:read, history)
          end
        end

        desc 'Show application history'
        params do
          requires :id, type: Integer, desc: 'Application history id'
        end
        get '/:id' do
          history = ::ApplicationHistory.find(params[:id])
          authorize!(:read, history)
          history
        end

        desc 'Create application history'
        params do
          requires :application_id, type: Integer, desc: 'Target application id'
          requires :domain, type: String, desc: 'Domain name to point this application'
          requires :url, type: String, desc: "Application's git repository or tar.gz url"
          optional :type, type: String, default: 'dynamic', desc: 'Application type (dynamic or static)'
          optional :protocol, type: String, default: 'git', desc: 'Application file transferred protocol'
          optional :revision, type: String, default: 'master', desc: "Application's git repository revision"
          optional :pre_deploy, type: String, desc: 'Shellscript to run before deploy'
          optional :post_deploy, type: String, desc: 'Shellscript to run after deploy'
          optional :parameters, type: String, default: '{}', desc: 'JSON string to apply additional configuration'
        end
        post '/' do
          authorize!(:create, ::ApplicationHistory)
          ::ApplicationHistory.create!(declared_params)
        end

        desc 'Update application history'
        params do
          requires :id, type: Integer, desc: 'Application history id'
          optional :domain, type: String, desc: 'Domain name to point this application'
          optional :url, type: String, desc: "Application's git repository or tar.gz url"
          optional :type, type: String, default: 'dynamic', desc: 'Application type (dynamic or static)'
          optional :protocol, type: String, default: 'git', desc: 'Application file transferred protocol'
          optional :revision, type: String, default: 'master', desc: "Application's git repository revision"
          optional :pre_deploy, type: String, desc: 'Shellscript to run before deploy'
          optional :post_deploy, type: String, desc: 'Shellscript to run after deploy'
          optional :parameters, type: String, default: '{}', desc: 'JSON string to apply additional configuration'
        end
        put '/:id' do
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
          history = ::ApplicationHistory.find(params[:id])
          authorize!(:destroy, history)
          history.destroy
          status 204
        end
      end
    end
  end
end
