module API
  module V1
    class PermissionAPI < API::V1::Base
      resource :roles do
        route_param :role_id do
          resource :permissions do
            desc 'List permissions'
            get '/' do
              role = Role.find(params[:role_id])
              authorize!(:read, role)
              role.permissions
            end

            desc 'Show permission'
            params do
              requires :role_id, type: Integer, desc: 'Target role id'
              requires :id, type: Integer, desc: 'Permission id'
            end
            get '/:id' do
              role = Role.find(params[:role_id])
              authorize!(:read, role)
              ::Permission.find(params[:id])
            end

            desc 'Create permission'
            params do
              requires :role_id, type: Integer, desc: 'Target role id'
              requires :model, type: String, desc: 'model name'
              requires :action, type: String, desc: 'action'
            end
            post '/' do
              role = Role.find(params[:role_id])
              authorize!(:update, role)
              actions = params[:action].split(',')
              if actions.count == 1
                ::Permission.create!(declared_params)
              else
                actions.each do |action|
                  role.add_permission(params[:model], action)
                end
                role.save!
                role.permissions.where(model: params[:model])
              end
            end

            desc 'Update permission'
            params do
              requires :role_id, type: Integer, desc: 'Target role id'
              requires :id, type: Integer, desc: 'Permission id'
              optional :model, type: String, desc: 'model name'
              optional :action, type: String, desc: 'action'
            end
            put '/:id' do
              role = Role.find(params[:role_id])
              authorize!(:update, role)
              permission = ::Permission.find(params[:id])
              permission.update_attributes!(declared_params)
              permission
            end

            desc 'Destroy permission'
            params do
              requires :role_id, type: Integer, desc: 'Target role id'
              requires :id, type: Integer, desc: 'Permission id'
            end
            delete '/:id' do
              role = Role.find(params[:role_id])
              authorize!(:update, role)
              permission = ::Permission.find(params[:id])
              permission.destroy
              status 204
            end
          end
        end
      end
    end
  end
end
