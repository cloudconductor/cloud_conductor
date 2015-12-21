module API
  module V1
    class AssignmentAPI < API::V1::Base
      resource :assignments do
        before do
          project = current_project(Assignment)
          @project_id = nil
          @project_id = project.id if project
        end

        after do
          track_api(@project_id)
        end

        desc 'List assignments'
        params do
          optional :project_id, type: Integer, desc: 'Project id'
          optional :account_id, type: Integer, desc: 'Account id'
        end
        get '/' do
          ::Assignment.eager_load(:project).where(params.slice(:project_id, :account_id).to_hash)
            .select do |assignment|
            can?(:read, assignment)
          end
        end

        desc 'Show assignment'
        params do
          requires :id, type: Integer, desc: 'Assignment id'
        end
        get '/:id' do
          assignment = ::Assignment.find(params[:id])
          authorize!(:read, assignment)
          assignment
        end

        desc 'Create assignment'
        params do
          requires :project_id, type: Integer, exists_id: :project, desc: 'Project id'
          requires :account_id, type: Integer, exists_id: :account, desc: 'Account id'
        end
        post '/' do
          project = ::Project.find_by(id: params[:project_id])
          authorize!(:read, project)
          authorize!(:create, ::Assignment, project: project)

          ::Assignment.create!(declared_params)
        end

        desc 'Destroy assignment'
        params do
          requires :id, type: Integer, desc: 'Assignment id'
        end
        delete '/:id' do
          assignment = ::Assignment.find(params[:id])
          authorize!(:destroy, assignment)
          assignment.destroy
          status 204
        end
      end
    end
  end
end
