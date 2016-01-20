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
            puts "11"
            audits = ::Audit.where(project_id: params[:project_id])
            puts "13"
          else
            audits = ::Audit.all
          end
          puts "17"
          puts audits
          audits.select do |audit|
            puts "19"
            can?(:read, audit)
          end
        end
      end
    end
  end
end
