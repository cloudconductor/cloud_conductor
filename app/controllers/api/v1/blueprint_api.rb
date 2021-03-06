module API
  module V1
    class BlueprintAPI < API::V1::Base
      resource :blueprints do
        before do
          project = current_project(Blueprint)
          @project_id = nil
          @project_id = project.id if project
        end

        after do
          track_api(@project_id)
        end

        desc 'List blueprints'
        params do
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/' do
          ::Blueprint.where(params.slice(:project_id).to_hash).select do |blueprint|
            can?(:read, blueprint)
          end
        end

        desc 'Show blueprint'
        params do
          requires :id, type: Integer, desc: 'Blueprint id'
        end
        get '/:id' do
          blueprint = ::Blueprint.find(params[:id])
          authorize!(:read, blueprint)
          blueprint
        end

        desc 'Create blueprint'
        params do
          requires :project_id, type: Integer, exists_id: :project, desc: 'Project id'
          requires :name, type: String, desc: 'Blueprint name'
          optional :description, type: String, desc: 'Blueprint description'
        end
        post '/' do
          project = ::Project.find_by(id: params[:project_id])
          authorize!(:read, project)
          authorize!(:create, ::Blueprint, project: project)
          ::Blueprint.create!(declared_params)
        end

        desc 'Update blueprint'
        params do
          requires :id, type: Integer, desc: 'Blueprint id'
          optional :name, type: String, desc: 'Blueprint name'
          optional :description, type: String, desc: 'Blueprint description'
        end
        put '/:id' do
          blueprint = ::Blueprint.find(params[:id])
          authorize!(:update, blueprint)
          blueprint.update_attributes!(declared_params)
          blueprint
        end

        desc 'Destroy blueprint'
        params do
          requires :id, type: Integer, desc: 'Blueprint id'
        end
        delete '/:id' do
          blueprint = ::Blueprint.find(params[:id])
          authorize!(:destroy, blueprint)
          blueprint.destroy
          status 204
        end

        desc 'Build blueprint history with images from blueprint'
        params do
          requires :blueprint_id, type: Integer, desc: 'Blueprint id'
        end
        post '/:blueprint_id/build' do
          blueprint = Blueprint.find(params[:blueprint_id])
          authorize!(:read, blueprint)
          authorize!(:create, BlueprintHistory, project: blueprint.project)
          history = BlueprintHistory.create!(declared_params)
          status 202
          history
        end
      end
    end
  end
end
