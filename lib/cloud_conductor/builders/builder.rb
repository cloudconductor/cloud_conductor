module CloudConductor
  module Builders
    class Builder
      def initialize(cloud, environment)
        @cloud = cloud
        @environment = environment
      end

      def build
        Log.info "Start creating environment(#{@environment.name}) on #{@cloud.name}"
        @environment.update_attribute(:status, :PROGRESS)

        build_infrastructure
        wait_for_leader_election(@environment)
        send_events(@environment)

        @environment.update_attribute(:status, :CREATE_COMPLETE)
        @environment.deployments.each do |deployment|
          deployment.update_attributes!(status: 'DEPLOY_COMPLETE')
        end
        Log.info "Created environment(#{@environment.name}) on #{@cloud.name}"
      rescue => e
        @environment.update_attribute(:status, :ERROR)
        Log.warn "Following errors have been occurred while creating environment(#{@environment.name}) on #{@cloud.name}"
        Log.warn e.message
        Log.debug e.backtrace
        raise
      end

      def destroy
        Log.info "Start destroying environment(#{@environment.name}) on #{@cloud.name}"

        destroy_infrastructure

        Log.info "Destroyed environment(#{@environment.name}) on #{@cloud.name}"
      rescue => e
        @environment.update_attribute(:status, :ERROR)
        Log.warn "Following errors have been occurred while destroying environment(#{@environment.name}) on #{@cloud.name}"
        Log.warn e.message
        Log.debug e.backtrace
        raise
      end

      private

      def build_infrastructure
        # This method will be implemented on subclasses
        fail 'Unimplement method'
      end

      def destroy_infrastructure
        # This method will be implemented on subclasses
        fail 'Unimplement method'
      end

      def wait_for_leader_election(environment)
        Timeout.timeout(CloudConductor::Config.system_build.timeout) do
          sleep 3 until environment.consul.running?
        end
      end

      def send_events(environment)
        environment.event.sync_fire(:configure, configure_payload(environment))
        environment.event.sync_fire(:restore, application_payload(environment))
        environment.event.sync_fire(:deploy, application_payload(environment)) unless environment.deployments.empty?
        environment.event.sync_fire(:spec)
      end

      def configure_payload(environment)
        payload = {}

        payload['cloudconductor/cloudconductor'] = {
          cloudconductor: {
            salt: OpenSSL::Digest::SHA256.hexdigest(environment.system.created_at.iso8601(6))
          }
        }
        payload['cloudconductor/environment_id'] = {
          environment_id: environment.id
        }
        payload['cloudconductor/system_domain'] = {
          name: environment.system.name,
          dns: environment.system.domain
        }

        environment.stacks.created.each do |stack|
          payload.deep_merge! stack.payload
        end

        payload
      end

      def application_payload(environment)
        return {} if environment.deployments.empty?

        environment.deployments.map(&:application_history).map(&:payload).inject(&:deep_merge)
      end

      def get_account_authentication_token(environment)
        environment.system.project.accounts.authentication_token
      end
    end
  end
end
