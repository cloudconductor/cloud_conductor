module API
  module V1
    class AccountAPI < API::V1::Base
      resource :accounts do
        desc 'List accounts'
        params do
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/' do
          if params[:project_id]
            project = ::Project.find(params[:project_id])
            authorize!(:read, project)
            authorize!(:read, ::Account, project: project)
            ::Account.joins(:assignments).where(assignments: { project: project })
          else
            ::Account.all.select do |account|
              can?(:read, account)
            end
          end
        end

        desc 'Show account'
        params do
          requires :id, type: Integer, desc: 'Account id'
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/:id' do
          account = ::Account.find(params[:id])
          if params[:project_id]
            project = ::Project.find(params[:project_id])
            authorize!(:read, project)
            authorize!(:read, account, project: project)
          else
            assignment = Assignment.arel_table[:account_id]
            project = ::Project.joins(:assignments)
                      .where(assignment.eq(account.id).or(assignment.eq(current_account.id)))
                      .select do |project|
              can?(:read, project) && can?(:read, account, project: project)
            end.first
            authorize!(:read, account, project: project)
          end
          account
        end

        desc 'Create account'
        params do
          requires :email, type: String, desc: 'Account email'
          requires :name, type: String, desc: 'Account username'
          requires :password, type: String, desc: 'Account password'
          requires :password_confirmation, type: String, desc: 'Account password confirmation'
          optional :admin, type: Integer, desc: 'Account role'
          optional :project_id, type: Integer, desc: 'Project id'
          optional :role_id, type: Integer, desc: 'Role id'
        end
        post '/' do
          if params[:project_id]
            project = ::Project.find(params[:project_id])
            authorize!(:read, project)
            role = project.roles.find(params[:role_id])
            authorize!(:read, role)

            authorize!(:create, ::Account, project: project)
            authorize!(:create, ::Assignment, project: project)
            account = ::Account.find_by(email: params[:email])
            unless account
              attributes = declared_params.except(:admin, :project_id, :role_id)
              account = ::Account.create(attributes)
            end
            assignment = account.assignments.find_by(project: project)
            if assignment
              assignment.roles << role unless assignment.roles.find_by_id(role.id)
            else
              account.assignments.build(project: project, roles: [role])
            end
            account.save!
            account
          else
            authorize!(:create, ::Account)
            authorize!(:update_admin, ::Account) if params[:admin] != 0
            ::Account.create!(declared_params)
          end
        end

        desc 'Update account'
        params do
          requires :id, type: Integer, desc: 'Account id'
          optional :email, type: String, desc: 'Account email'
          optional :name, type: String, desc: 'Account username'
          optional :password, type: String, desc: 'Account old password'
          optional :password_confirmation, type: String, desc: 'Account new password confirmation'
          optional :admin, type: Integer, desc: 'Account role'
        end
        put '/:id' do
          account = ::Account.find(params[:id])
          authorize!(:update, account)
          authorize!(:update_admin, ::Account) if params[:admin] != 0
          account.update_attributes!(declared_params)
          account
        end

        desc 'Destroy account'
        params do
          requires :id, type: Integer, desc: 'Account id'
        end
        delete '/:id' do
          account = ::Account.find(params[:id])
          authorize!(:destroy, account)
          error!('Cannot delete your own account.', 405) if current_account == account
          account.destroy
          status 204
        end
      end
    end
  end
end
