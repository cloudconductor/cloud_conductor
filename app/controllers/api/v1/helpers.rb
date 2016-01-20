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
          unless subject.is_a?(Audit)
            if subject.is_a?(Project)
              project = subject
            elsif !subject.is_a?(Account)
              project = subject.project
            end
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

      def current_project(model)
        project = nil
        model_object = nil
        model_list = { project_id: Project,
                       application_id: Application,
                       system_id: System,
                       cloud_id: Cloud,
                       blueprint_id: Blueprint,
                       assignment_id: Assignment,
                       role_id: Role,
                       id: model }
        model_list.each_key do |key|
          model_object = model_list[key].find_by_id(params[key]) if params.key?(key)
          break if model_object
        end
        if model_object.class == Project
          project = model_object
        elsif model_object
          project = model_object.project
        end
        project
      end

      def track_api(project_id)
        track_method = %w(PUT POST DELETE)
        if track_method.include?(request.request_method)
          account_id = current_account.id if current_account
          ::Audit.create!(ip: request.ip, account: account_id, status: status, request: request.url, project_id: project_id)
        end
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
