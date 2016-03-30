module CloudConductor
  module Updaters
    class Updater
      def initialize(cloud, environment)
        @cloud = cloud
        @environment = environment
      end

      def update
        @nodes = get_nodes(@environment)
        Log.info "Start updating environment(#{@environment.name}) on #{@cloud.name}"
        @environment.update_attribute(:status, :PROGRESS)

        update_infrastructure
        send_events(@environment)

        @environment.update_attribute(:status, :CREATE_COMPLETE)
        Log.info "Updated environment(#{@environment.name}) on #{@cloud.name}"
      rescue => e
        @environment.update_attribute(:status, :ERROR)
        Log.warn "Following errors have been occurred while updating environment(#{@environment.name}) on #{@cloud.name}"
        Log.warn e.message
        Log.debug e.backtrace
        raise
      end

      private

      def update_infrastructure
        # This method will be implemented on subclasses
        fail 'Unimplement method'
      end

      def send_events(environment)
        target_nodes = get_nodes(environment) - @nodes

        environment.consul.kv.delete('cloudconductor/servers', true)
        environment.event.sync_fire(:configure)
        unless target_nodes.empty?
          environment.event.sync_fire(:restore, {}, node: target_nodes)
          environment.event.sync_fire(:deploy, {}, node: target_nodes) unless environment.deployments.empty?
        end
        environment.event.sync_fire(:spec)
      end

      def get_nodes(environment)
        environment.consul.catalog.nodes.map { |node| node[:node] }
      end
    end
  end
end
