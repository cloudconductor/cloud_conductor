module API
  module V1
    class AuditAPI < API::V1::Base
      resource :audits do
        desc 'List audits'
        params do
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/' do
          export_limit = CloudConductor::Config.audit_log.export_limit
          if params[:project_id]
            audits = ::Audit.where(project_id: params[:project_id]).last(export_limit)
          else
            audits = ::Audit.all.last(export_limit)
          end
          audits.select do |audit|
            can?(:read, audit)
          end
        end
      end
    end
  end
end
