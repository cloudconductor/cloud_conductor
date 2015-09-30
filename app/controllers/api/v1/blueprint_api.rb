module API
  module V1
    class BlueprintAPI < API::V1::Base
      resource :blueprints do
        desc 'List blueprints'
        get '/' do
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
          blueprint = ::Blueprint.create!(declared_params)
          status 202
          blueprint
        end

        desc 'Update blueprint'
        params do
          requires :id, type: Integer, desc: 'Blueprint id'
          optional :name, type: String, desc: 'Blueprint name'
          optional :description, type: String, desc: 'Blueprint description'
          optional :patterns_attributes, type: Array, desc: 'Pattern repository url and revision' do
            optional :url, type: String, desc: 'URL of repository that contains pattern'
            optional :revision, type: String, desc: 'revision of repository'
          end
        end
        put '/:id' do
          blueprint = ::Blueprint.find(params[:id])
          authorize!(:update, blueprint)
          blueprint.update_attributes!(declared_params)
          status 202
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

        desc 'Get blueprint parameters'
        params do
          requires :id, type: Integer, desc: 'Blueprint id'
        end
        get '/:id/parameters' do
          blueprint = ::Blueprint.find(params[:id])
          authorize!(:read, blueprint)
          blueprint.patterns.each_with_object({}) do |pattern, hash|
            hash[pattern.name] = pattern.filtered_parameters
          end
        end
      end
    end
  end
end
