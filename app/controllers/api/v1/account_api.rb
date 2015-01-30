module API
  module V1
    class AccountAPI < API::V1::Base
      resource :accounts do
        desc 'List accounts'
        get '/' do
          authorize!(:read, ::Account)
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
          account = ::Account.create!(declared_params)
          status 200
          account
        end

        desc 'Update account'
        params do
          requires :id, type: Integer, desc: 'Account id'
          optional :email, type: String, desc: 'Account email'
          optional :name, type: String, desc: 'Account username'
          optional :old_password, type: String, desc: 'Account old password'
          optional :new_password, type: String, desc: 'Account new password'
          optional :new_password_confirmation, type: String, desc: 'Account new password confirmation'
          optional :admin, type: Integer, desc: 'Account role'
        end
        put '/:id' do
          account = ::Account.find(params[:id])
          authorize!(:update, account)
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
          account.destroy
          status 204
        end
      end
    end
  end
end
