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
  class SystemBuilder # rubocop:disable ClassLength
    TIMEOUT = 1800
    CHECK_PERIOD = 3

    def initialize(system)
      @clouds = system.candidates.sorted.map(&:cloud)
      @system = system
    end

    def build # rubocop:disable MethodLength
      ActiveRecord::Base.connection_pool.with_connection do
        @clouds.each do |cloud|
          begin
            Log.info "Start creating stacks of system(#{@system.name}) on #{cloud.name}"
            until @system.stacks.select(&:pending?).empty?
              platforms = @system.stacks.select(&:pending?).select(&:platform?)
              optionals = @system.stacks.select(&:pending?).select(&:optional?)
              stack = (platforms + optionals).first
              stack.cloud = cloud
              stack.status = :READY
              stack.save!

              wait_for_finished(stack, TIMEOUT)

              update_system stack.outputs if stack.platform?

              stack.status = :CREATE_COMPLETE
              stack.save!

              stack.client.post_process
            end

            finish_system if @system.reload

            Log.info "Created all stacks on system(#{@system.name}) on #{cloud.name}"
            break
          rescue => e
            Log.warn "Some error has occurred while creating stacks on system(#{@system.name}) on #{cloud.name}"
            Log.warn e.message
            reset_stacks
          end
        end

        unless @system.status == :CREATE_COMPLETE
          @system.stacks.each do |stack|
            stack.status = :ERROR
            stack.save!
          end
        end
      end
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

        unless %i(CREATE_IN_PROGRESS CREATE_COMPLETE).include? stack.status
          fail "Unknown error has occurred while create stack(#{stack.status})"
        end

        next if status == :CREATE_IN_PROGRESS

        if stack.pattern.type == :platform
          outputs = stack.outputs
          next if outputs['FrontendAddress'].nil?

          ip_address = outputs['FrontendAddress']
          Log.debug "  Outputs has FrontendAddress(#{ip_address})"

          consul = Consul::Client.connect host: ip_address
          next unless consul.running?

          serf = Serf::Client.new host: ip_address
          status, _results = serf.call('info')
          next unless status.success?
        end

        break
      end
    end
    # rubocop:enable MethodLength, CyclomaticComplexity, PerceivedComplexity

    def update_system(outputs)
      Log.info 'Platform stack has created. CloudConductor will register host to zabbix/DNS.'
      @system.ip_address = outputs['FrontendAddress']
      @system.monitoring_host = @system.domain
      @system.template_parameters = outputs.except('FrontendAddress').to_json
      @system.save!
    end

    def finish_system
      payload = {
        cloudconductor: {
          patterns: {
          }
        }
      }

      @system.stacks.created.each do |stack|
        payload[:cloudconductor][:patterns].deep_merge! stack.payload
      end
      @system.serf.call('event', 'configure', payload)

      sleep 3
      @system.send_application_payload

      sleep 3
      @system.serf.call('event', 'restore', {})

      sleep 3
      @system.deploy_applications
    end

    def reset_stacks
      Log.info 'Reset all stacks.'
      @system.ip_address = nil
      @system.monitoring_host = nil
      @system.template_parameters = '{}'
      stacks = @system.stacks.map(&:dup)
      @system.destroy_stacks
      @system.stacks = stacks

      @system.save!
    end
  end
end
