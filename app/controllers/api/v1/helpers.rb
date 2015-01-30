module API
  module V1
    module Helpers
      def require_no_authentication
        env['api.endpoint'].namespace == '/tokens'
      end

      def authenticate_account_from_token!
        conditions = params.slice(Devise::TokenAuthenticatable.token_authentication_key)
        account = Account.find_for_token_authentication(conditions)
        if account
          env['current_account'] = account
        else
          # Insert random sleep to make token prediction more difficult by timing attack.
          sleep((200 + rand(200)) / 1000.0)
          error!('Unauthorized', 401)
        end
      end

      def authorize!(*args)
        current_ability.authorize!(*args)
      end

      def can?(*args)
        current_ability.can?(*args)
      end

      def cannot?(*args)
        current_ability.cannot?(*args)
      end

      def current_ability
        ::Ability.new(current_account)
      end

      def current_account
        env['current_account']
      end

      def declared_params
        declared(params, include_missing: false)
      end

      def permitted_params(*args)
        ActionController::Parameters.new(params.slice(*args)).permit(*args)
      end
    end
  end
end
