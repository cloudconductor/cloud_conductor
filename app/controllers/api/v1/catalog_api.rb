module API
  module V1
    class CatalogAPI < API::V1::Base
      resource :blueprints do
        route_param :blueprint_id do
          resource :catalogs do
            desc 'List catalogs'
            get '/' do
              Blueprint.find(params[:blueprint_id]).catalogs.select do |catalog|
                can?(:read, catalog)
              end
            end

            desc 'Show catalog'
            params do
              requires :id, type: Integer, desc: 'Catalog id'
            end
            get '/:id' do
              blueprint = ::Blueprint.find(params[:blueprint_id])
              authorize!(:read, blueprint)
              catalog = blueprint.catalogs.find(params[:id])
              authorize!(:read, catalog)
              catalog
            end

            desc 'Add pattern to blueprint as catalog'
            params do
              requires :blueprint_id, type: Integer, desc: 'Blueprint id'
              requires :pattern_id, type: Integer, desc: 'Pattern id'
              optional :revision, type: String, desc: 'Revision on pattern'
              optional :os_version, type: String, desc: 'Operationg system version'
            end
            post '/' do
              blueprint = Blueprint.find(params[:blueprint_id])
              authorize!(:update, blueprint)
              authorize!(:create, Catalog)
              Catalog.create!(declared_params)
            end

            desc 'Update catalog in blueprint'
            params do
              requires :id, type: Integer, desc: 'Catalog id'
              optional :revision, type: String, desc: 'Revision on pattern'
              optional :os_version, type: String, desc: 'Operationg system version'
            end
            put '/:id' do
              blueprint = Blueprint.find(params[:blueprint_id])
              authorize!(:update, blueprint)
              catalog = blueprint.catalogs.find(params[:id])
              authorize!(:update, catalog)
              catalog.update_attributes!(declared_params)
              catalog
            end

            desc 'Remove pattern from blueprint'
            params do
              requires :id, type: Integer, desc: 'Catalog id'
            end
            delete '/:id' do
              blueprint = Blueprint.find(params[:blueprint_id])
              authorize!(:update, blueprint)
              catalog = blueprint.catalogs.find(params[:id])
              authorize!(:destroy, catalog)
              catalog.destroy
              status 204
            end
          end
        end
      end
    end
  end
end
