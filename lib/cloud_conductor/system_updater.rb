# -*- coding: utf-8 -*-
# Copyright 2014 TIS Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
module CloudConductor
  class SystemUpdater # rubocop:disable ClassLength
    TIMEOUT = 1800
    CHECK_PERIOD = 3

    def initialize(environment)
      @environment = environment
      @nodes = get_nodes(@environment)
    end

    def update # rubocop:disable MethodLength
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          cloud = @environment.stacks.first.cloud
          Log.info "Start updating stacks of environment(#{@environment.name}) on #{cloud.name}"
          @environment.status = :PROGRESS
          @environment.save!

          until @environment.stacks.select(&:pending?).empty?
            platforms = @environment.stacks.select(&:pending?).select(&:platform?)
            optionals = @environment.stacks.select(&:pending?).select(&:optional?)
            stack = (platforms + optionals).first
            stack.status = :READY_FOR_UPDATE
            stack.save!

            wait_for_finished(stack, TIMEOUT)

            update_environment stack.outputs if stack.platform?

            stack.status = :CREATE_COMPLETE
            stack.save!

            stack.client.post_process
          end

          finish_environment if @environment.reload

          Log.info "Updated all stacks on environment(#{@environment.name}) on #{cloud.name}"
          break
        rescue => e
          Log.warn "Some error has occurred while updating stacks on environment(#{@environment.name}) on #{cloud.name}"
          Log.warn e.message
          @environment.status = :ERROR
          @environment.save!
        end
      end

      @environment.stacks.each do |stack|
        stack.status = :ERROR
        stack.save!
      end unless @environment.status == :CREATE_COMPLETE
    end

    private

    # rubocop:disable MethodLength, CyclomaticComplexity, PerceivedComplexity
    def wait_for_finished(stack, timeout)
      elapsed_time = 0

      Log.debug "Wait until status of stack has changed for #{stack.name}"
      loop do
        sleep CHECK_PERIOD
        elapsed_time += CHECK_PERIOD
        fail "Target stack(#{stack.name}) exceed timeout(#{timeout} sec)" if elapsed_time > timeout

        fail "Target stack(#{stack.name}) record is already deleted" unless Stack.where(id: stack.id).exists?

        status = stack.status

        unless %i(UPDATE_IN_PROGRESS UPDATE_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_COMPLETE CREATE_COMPLETE).include? status
          fail "Unknown error has occurred while update stack(#{status})"
        end

        next if status == :UPDATE_IN_PROGRESS || status == :UPDATE_COMPLETE_CLEANUP_IN_PROGRESS

        if stack.pattern.type == 'platform'
          outputs = stack.outputs
          next if outputs['FrontendAddress'].nil?

          ip_address = outputs['FrontendAddress']
          Log.debug "  Outputs has FrontendAddress(#{ip_address})"

          consul = Consul::Client.new ip_address, CloudConductor::Config.consul.port, CloudConductor::Config.consul.options.save
          next unless consul.running?
        end

        break
      end
    end
    # rubocop:enable MethodLength, CyclomaticComplexity, PerceivedComplexity

    def update_environment(outputs)
      Log.info 'Platform stack has updated.'
      @environment.ip_address = outputs['FrontendAddress']
      @environment.platform_outputs = outputs.except('FrontendAddress').to_json
      @environment.save!
    end

    def finish_environment
      @environment.event.sync_fire(:configure, configure_payload(@environment))
      target_node = get_nodes(@environment) - @nodes
      unless target_node.empty?
        @environment.event.sync_fire(:restore, {}, node: target_node)
        @environment.event.sync_fire(:deploy, {}, node: target_node) unless @environment.deployments.empty?
      end
      @environment.event.sync_fire(:spec)

      @environment.status = :CREATE_COMPLETE
      @environment.deployments.each do |deployment|
        deployment.update_attributes!(status: 'DEPLOY_COMPLETE')
      end
      @environment.save!
    end

    private

    def configure_payload(environment)
      payload = {
        cloudconductor: {
          patterns: {
          }
        }
      }

      environment.stacks.created.each do |stack|
        payload[:cloudconductor][:patterns].deep_merge! stack.payload
      end

      payload
    end

    def get_nodes(environment)
      environment.consul.catalog.nodes.map { |node| node[:node] }
    end
  end
end
