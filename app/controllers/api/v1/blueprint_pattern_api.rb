module API
  module V1
    class BlueprintPatternAPI < API::V1::Base
      resource :blueprints do
        route_param :blueprint_id do
          resource :patterns do
            desc 'List patterns that are contained blueprint'
            get '/' do
              Blueprint.find(params[:blueprint_id]).blueprint_patterns.select do |relation|
                can?(:read, relation)
              end
            end

            desc 'Show pattern that is contained blueprint'
            params do
              requires :pattern_id, type: Integer, desc: 'Pattern id'
            end
            get '/:pattern_id' do
              blueprint = ::Blueprint.find(params[:blueprint_id])
              authorize!(:read, blueprint)
              relation = blueprint.blueprint_patterns.where(pattern_id: params[:pattern_id]).first!
              authorize!(:read, relation)
              relation
            end

            desc 'Add pattern to blueprint'
            params do
              requires :blueprint_id, type: Integer, desc: 'Blueprint id'
              requires :pattern_id, type: Integer, desc: 'Pattern id'
              optional :revision, type: String, desc: 'Revision on pattern'
              optional :os_version, type: String, desc: 'Operationg system version'
            end
            post '/' do
              blueprint = Blueprint.find(params[:blueprint_id])
              authorize!(:update, blueprint)
              authorize!(:create, BlueprintPattern)
              BlueprintPattern.create!(declared_params)
            end

            desc 'Update relation in blueprint'
            params do
              requires :pattern_id, type: Integer, desc: 'Pattern id'
              optional :revision, type: String, desc: 'Revision on pattern'
              optional :os_version, type: String, desc: 'Operationg system version'
            end
            put '/:pattern_id' do
              blueprint = Blueprint.find(params[:blueprint_id])
              authorize!(:update, blueprint)
              relation = blueprint.blueprint_patterns.where(pattern_id: params[:pattern_id]).first!
              authorize!(:update, relation)
              relation.update_attributes!(declared_params)
              relation
            end

            desc 'Remove pattern from blueprint'
            params do
              requires :pattern_id, type: Integer, desc: 'Pattern id'
            end
            delete '/:pattern_id' do
              blueprint = Blueprint.find(params[:blueprint_id])
              authorize!(:update, blueprint)
              relation = blueprint.blueprint_patterns.where(pattern_id: params[:pattern_id]).first!
              authorize!(:destroy, relation)
              relation.destroy
              status 204
            end
          end
        end
      end
    end
  end
end