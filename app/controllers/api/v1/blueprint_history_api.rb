module API
  module V1
    class BlueprintHistoryAPI < API::V1::Base
      resource :blueprints do
        route_param :blueprint_id do
          resource :histories do
            desc 'List blueprint histories'
            get '/' do
              Blueprint.find(params[:blueprint_id]).histories.select do |history|
                can?(:read, history)
              end
            end

            desc 'Get blueprint history parameters'
            params do
              requires :id, type: Integer, desc: 'Blueprint history id'
            end
            get '/:id/parameters' do
              blueprint = ::Blueprint.find(params[:blueprint_id])
              authorize!(:read, blueprint)
              history = blueprint.histories.find(params[:id])
              history.patterns.each_with_object({}) do |pattern, hash|
                hash[pattern.name] = pattern.filtered_parameters
              end
            end

            desc 'Delete blueprint history'
            params do
              requires :id, type: Integer, desc: 'Blueprint history id'
            end
            delete '/:id' do
              blueprint = Blueprint.find(params[:blueprint_id])
              authorize!(:update, blueprint)
              history = blueprint.histories.find(params[:id])
              authorize!(:destroy, history)
              history.destroy
              status 204
            end
          end
        end
      end
    end
  end
end
