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
          error!('Requires valid auth_token.', 401)
        end
      end

      def find_project(subject)
        project = nil
        unless subject.class == Class
          if subject.is_a?(Project)
            project = subject
          elsif !subject.is_a?(Account)
            project = subject.project
          end
        end
        project
      end

      def find_project_by_account(account, *args)
        account.projects.find do |project|
          project.id == args.pop[:project].id
        end if args.last[:project]
      end

      def create_ability(subject, *args)
        project = nil
        if args.last.is_a?(Hash) && args.last.key?(:project)
          if subject.class == Class
            project = args.pop[:project]
          elsif subject.is_a?(Account)
            project = find_project_by_account(subject, *args)
          else
            project = find_project(subject)
          end
        else
          project = find_project(subject)
        end
        Ability.new(current_account, project)
      end

      def track_api
        account_id = current_account.id if current_account
        project_id = request.params[:project_id] if request.params.key?(:project_id)
        ::Audit.create!(ip: request.ip, account: account_id, status: status, request: request.url, project_id: project_id)
      end

      def authorize!(action, subject, *args)
        create_ability(subject, *args).authorize!(action, subject, *args)
      end

      def can?(action, subject, *args)
        create_ability(subject, *args).can?(action, subject, *args)
      end

      def cannot?(action, subject, *args)
        create_ability(subject, *args).cannot?(action, subject, *args)
      end

      def current_ability
        ::Ability.new(current_account)
      end

      def current_account
        env['current_account']
      end

      def declared_params
        declared(params, include_missing: false).to_hash.with_indifferent_access
      end

      def permitted_params(*args)
        ActionController::Parameters.new(params.slice(*args)).permit(*args)
      end
    end
  end
end
