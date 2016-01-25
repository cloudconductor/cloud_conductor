module API
  module V1
    class AuditAPI < API::V1::Base
      resource :audits do
        desc 'List audits'
        params do
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/' do
          if params[:project_id]
            audits = ::Audit.where(project_id: params[:project_id])
          else
            audits = ::Audit.all
          end
          audits.select do |audit|
            can?(:read, audit)
          end
        end
      end
    end
  end
end
