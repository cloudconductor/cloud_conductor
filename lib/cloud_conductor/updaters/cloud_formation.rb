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
  module Updaters
    class CloudFormation < CloudConductor::Updaters::Updater
      CHECK_PERIOD = 3

      def initialize(cloud, environment)
        super
      end

      private

      def update_infrastructure
        @nodes = get_nodes(@environment)
        until @environment.stacks.select(&:pending?).empty?
          platforms = @environment.stacks.select(&:pending?).select(&:platform?)
          optionals = @environment.stacks.select(&:pending?).select(&:optional?)
          stack = (platforms + optionals).first
          stack.status = :READY_FOR_UPDATE
          stack.save!

          if stack.progress?
            wait_for_finished(stack, CloudConductor::Config.system_build.timeout)

            update_environment stack.outputs if stack.platform?

            stack.status = :CREATE_COMPLETE
            stack.save!
          end

          stack.client.post_process
        end
      rescue
        @environment.stacks.each { |stack| stack.update_attribute(:status, :ERROR) }
        raise
      end

      def wait_for_finished(stack, timeout) # rubocop:disable MethodLength, CyclomaticComplexity, PerceivedComplexity
        elapsed_time = 0

        Log.debug "Wait until status of stack has changed for #{stack.name}"
        loop do
          sleep CHECK_PERIOD
          elapsed_time += CHECK_PERIOD
          fail "Target stack(#{stack.name}) exceed timeout(#{timeout} sec)" if elapsed_time > timeout

          fail "Target stack(#{stack.name}) record is already deleted" unless Stack.where(id: stack.id).exists?

          status = stack.status

          unless %i(UPDATE_IN_PROGRESS UPDATE_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_COMPLETE CREATE_COMPLETE).include? status
            failed_events = stack.events.select { |event| %w(CREATE_FAILED UPDATE_FAILED).include?(event.resource_status) }
            details = failed_events.map do |event|
              format('  %s %s %s(%s):%s',
                     event.timestamp.localtime.iso8601,
                     event.resource_status,
                     event.resource_type,
                     event.logical_resource_id,
                     event.resource_status_reason
                    )
            end
            fail "Some error has occurred while create stack(#{status})\n#{details.join("\n")}"
          end

          next if status == :UPDATE_IN_PROGRESS || status == :UPDATE_COMPLETE_CLEANUP_IN_PROGRESS

          if stack.pattern_snapshot.type == 'platform'
            outputs = stack.outputs
            next if outputs['ConsulAddresses'].nil?

            Log.debug "  Outputs has ConsulAddresses(#{outputs['ConsulAddresses']})"
          end

          break
        end
      end

      def update_environment(outputs)
        Log.info 'Platform stack has updated.'
        @environment.frontend_address = outputs['FrontendAddress']
        @environment.consul_addresses = outputs['ConsulAddresses']
        @environment.platform_outputs = outputs.except('FrontendAddress', 'ConsulAddresses').to_json
        @environment.save!
      end

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
end
