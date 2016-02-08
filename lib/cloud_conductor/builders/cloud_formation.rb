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
  module Builders
    class CloudFormation < CloudConductor::Builders::Builder
      CHECK_PERIOD = 3

      def initialize(cloud, environment)
        super
      end

      private

      def build_infrastructure
        until @environment.stacks.select(&:pending?).empty?
          platforms = @environment.stacks.select(&:pending?).select(&:platform?)
          optionals = @environment.stacks.select(&:pending?).select(&:optional?)
          stack = (platforms + optionals).first
          stack.client = @cloud.client
          stack.cloud = @cloud
          stack.status = :READY_FOR_CREATE
          stack.save!

          if stack.progress?
            wait_for_finished(stack, CloudConductor::Config.system_build.timeout)

            update_environment stack.outputs if stack.platform?

            stack.status = :CREATE_COMPLETE
            stack.save!
          end

          stack.client.post_process
        end
      rescue => e
        @environment.stacks.each { |stack| stack.update_attribute(:status, :ERROR) }
        reset_stacks
        raise e
      end

      def destroy_infrastructure
        stacks = @environment.stacks
        platforms = stacks.select(&:platform?)
        optionals = stacks.select(&:optional?)
        stacks.delete_all

        begin
          optionals.each(&:destroy)
          Timeout.timeout(CloudConductor::Config.system_build.timeout) do
            sleep 10 until optionals.all?(&stack_destroyed?)
          end
        rescue Timeout::Error
          Log.warn "Exceeded timeout while destroying stacks #{optionals}"
        ensure
          platforms.each(&:destroy)
        end
      end

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

          unless %i(CREATE_IN_PROGRESS CREATE_COMPLETE).include? status
            failed_events = stack.events.select { |event| %w(CREATE_FAILED).include?(event[:resource_status]) }
            details = failed_events.map do |event|
              format('  %s %s %s(%s):%s',
                     event[:timestamp],
                     event[:resource_status],
                     event[:resource_type],
                     event[:logical_resource_id],
                     event[:resource_status_reason]
                    )
            end
            fail "Some error has occurred while create stack(#{status})\n#{details.join("\n")}"
          end

          next if status == :CREATE_IN_PROGRESS

          if stack.pattern_snapshot.type == 'platform'
            outputs = stack.outputs
            next if outputs['ConsulAddresses'].nil?

            consul_addresses = outputs['ConsulAddresses']
            Log.debug "  Outputs has ConsulAddresses(#{consul_addresses})"

            consul_config = CloudConductor::Config.consul
            consul = Consul::Client.new consul_addresses, consul_config.port, consul_config.options.save
            next unless consul.running?
          end

          break
        end
      end
      # rubocop:enable MethodLength, CyclomaticComplexity, PerceivedComplexity

      def update_environment(outputs)
        Log.info 'Platform stack has created.'
        @environment.frontend_address = outputs['FrontendAddress']
        @environment.consul_addresses = outputs['ConsulAddresses']
        @environment.platform_outputs = outputs.except('FrontendAddress', 'ConsulAddresses').to_json
        @environment.save!
      end

      def reset_stacks
        Log.info 'Reset all stacks.'
        stacks = @environment.stacks.map(&:dup)

        @environment.status = :ERROR
        @environment.frontend_address = nil
        @environment.consul_addresses = nil
        @environment.platform_outputs = '{}'
        @environment.save!

        destroy_infrastructure

        @environment.stacks = stacks
      end

      def stack_destroyed?
        lambda do |stack|
          return true unless stack.exists_on_cloud?
          [:DELETE_COMPLETE, :DELETE_FAILED].include? stack.cloud.client.get_stack_status(stack.name)
        end
      end
    end
  end
end
