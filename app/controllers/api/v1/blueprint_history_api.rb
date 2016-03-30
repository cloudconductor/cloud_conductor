module API
  module V1
    class BlueprintHistoryAPI < API::V1::Base
      resource :blueprints do
        route_param :blueprint_id do
          resource :histories do
            before do
              project = current_project(BlueprintHistory)
              @project_id = nil
              @project_id = project.id if project
            end

            after do
              track_api(@project_id)
            end

            desc 'List blueprint histories'
            get '/' do
              Blueprint.find(params[:blueprint_id]).histories.select do |history|
                can?(:read, history)
              end
            end

            desc 'Get blueprint history parameters'
            params do
              requires :ver, type: Integer, desc: 'Blueprint history version'
              optional :cloud_ids, type: String, desc: 'Cloud ids to build environment'
            end
            get '/:ver/parameters' do
              blueprint = ::Blueprint.find(params[:blueprint_id])
              authorize!(:read, blueprint)
              history = blueprint.histories.where(version: params[:ver]).first!

              providers = history.providers
              if params[:cloud_ids]
                clouds = params[:cloud_ids].split(/,\s*/).map { |cloud_id| Cloud.find(cloud_id).type }
                providers = history.providers.slice(*clouds)
              end
              providers = providers.map { |_, providers| providers.first }.uniq
              history.pattern_snapshots.each_with_object({}) do |pattern, hash|
                hash[pattern.name] = pattern.filtered_parameters(false, clouds, providers)
              end
            end

            desc 'Get blueprint history'
            params do
              requires :ver, type: Integer, desc: 'Blueprint history version'
            end
            get '/:ver' do
              blueprint = ::Blueprint.find(params[:blueprint_id])
              authorize!(:read, blueprint)
              history = blueprint.histories.where(version: params[:ver]).first!
              history.as_json(methods: [:status, :pattern_snapshots])
            end

            desc 'Delete blueprint history'
            params do
              requires :ver, type: Integer, desc: 'Blueprint history version'
            end
            delete '/:ver' do
              blueprint = Blueprint.find(params[:blueprint_id])
              authorize!(:update, blueprint)
              history = blueprint.histories.where(version: params[:ver]).first!
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
