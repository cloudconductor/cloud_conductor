module API
  module V1
    class AccountAPI < API::V1::Base
      resource :accounts do
        desc 'List accounts'
        get '/' do
          ::Account.all.select do |account|
            can?(:read, account)
          end
        end

        desc 'Show account'
        params do
          requires :id, type: Integer, desc: 'Account id'
        end
        get '/:id' do
          account = ::Account.find(params[:id])
          authorize!(:read, account)
          account
        end

        desc 'Create account'
        params do
          requires :email, type: String, desc: 'Account email'
          requires :name, type: String, desc: 'Account username'
          requires :password, type: String, desc: 'Account password'
          requires :password_confirmation, type: String, desc: 'Account password confirmation'
          optional :admin, type: Integer, desc: 'Account role'
        end
        post '/' do
          authorize!(:create, ::Account)
          authorize!(:update_admin, ::Account) if params[:admin] != 0
          ::Account.create!(declared_params)
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
