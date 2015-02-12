module API
  module V1
    class BlueprintAPI < API::V1::Base
      resource :blueprints do
        desc 'List blueprints'
        get '/' do
          authorize!(:read, ::Blueprint)
          ::Blueprint.all.select do |blueprint|
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
          requires :project_id, type: Integer, desc: 'Project id'
          requires :name, type: String, desc: 'Blueprint name'
          optional :description, type: String, desc: 'Blueprint description'
          requires :patterns_attributes, type: Array, desc: 'Pattern repository url and revision' do
            requires :url, type: String, desc: 'URL of repository that contains pattern'
            requires :revision, type: String, desc: 'revision of repository'
          end
        end
        post '/' do
          authorize!(:create, ::Blueprint)
          ::Blueprint.create!(declared_params)
        end

        desc 'Update blueprint'
        params do
          requires :id, type: Integer, desc: 'Blueprint id'
          requires :project_id, type: Integer, desc: 'Project id'
          optional :name, type: String, desc: 'Blueprint name'
          optional :description, type: String, desc: 'Blueprint description'
          optional :patterns_attributes, type: Array, desc: 'Pattern repository url and revision'
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
      end
    end
  end
end
