module API
  module V1
    class AssignmentRoleAPI < API::V1::Base
      resource :assignments do
        route_param :assignment_id do
          resource :roles do
            desc 'List assignment roles'
            get '/' do
              assignment = ::Assignment.find(params[:assignment_id])
              authorize!(:read, assignment)
              assignment.assignment_roles.select do |assignment_role|
                can?(:read, assignment_role.role)
              end
            end

            desc 'Show assignment role'
            params do
              requires :id, type: Integer, desc: 'AssignmentRole id'
            end
            get '/:id' do
              assignment = ::Assignment.find(params[:assignment_id])
              authorize!(:read, assignment)
              assignment.assignment_roles.find(params[:id])
            end

            desc 'Create assignment role'
            params do
              requires :assignment_id, type: Integer, desc: 'Target assignment_id'
              requires :role_id, type: Integer, desc: 'Target role id'
            end
            post '/' do
              assignment = ::Assignment.find(params[:assignment_id])
              authorize!(:update, assignment)

              ::AssignmentRole.create!(declared_params)
            end

            desc 'Destroy assignment role'
            params do
              requires :id, type: Integer, desc: 'AssignmentRole id'
            end
            delete '/:id' do
              assignment_role = ::AssignmentRole.find(params[:id])
              authorize!(:update, assignment_role.assignment)

              assignment_role.destroy
              status 204
            end
          end
        end
      end
    end
  end
end
