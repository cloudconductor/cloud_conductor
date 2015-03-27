module API
  module V1
    class TokenAPI < API::V1::Base
      resources 'tokens' do
        desc 'Request authentication and get access token'
        params do
          requires :email, type: String
          requires :password, type: String
        end
        post '/' do
          account = Account.find_by(email: params[:email])
          if account && account.valid_password?(params[:password])
            account.ensure_authentication_token!
            { auth_token: account.authentication_token }
          else
            error!('Authentication failed. Invalid email or password.', 401)
          end
        end
      end
    end
  end
end
