require 'validators/exists_id'

module API
  module V1
    class Base < Grape::API
      def self.inherited(subclass)
        super
        subclass.instance_eval do
          helpers API::V1::Helpers

          before do
            authenticate_account_from_token! unless require_no_authentication
          end

          rescue_exceptions
        end
      end

      def self.rescue_exceptions
        rescue_from ActiveRecord::RecordNotFound do |e|
          # logger.warn()
          error_response(message: e.message, status: 404)
        end

        rescue_from ActiveRecord::RecordInvalid do |e|
          # logger.warn()
          error_response(message: e.message, status: 400)
        end

        rescue_from Grape::Exceptions::ValidationErrors do |e|
          # logger.warn()
          error_response(message: e.message, status: 400)
        end

        rescue_from CanCan::AccessDenied do |e|
          # logger.warn()
          error_response(message: e.message, status: 403)
        end

        rescue_from :all do |e|
          # logger.error()
          error_response(message: "#{e.message}", status: 500)
        end
      end
    end
  end
end
