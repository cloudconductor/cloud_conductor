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

    def initialize(environment)
      @clouds = environment.candidates.sorted.map(&:cloud)
      @environment = environment
    end

    def build # rubocop:disable MethodLength
      ActiveRecord::Base.connection_pool.with_connection do
        @clouds.each do |cloud|
          begin
            Log.info "Start creating stacks of environment(#{@environment.name}) on #{cloud.name}"
            @environment.status = :PROGRESS
            @environment.save!

            until @environment.stacks.select(&:pending?).empty?
              platforms = @environment.stacks.select(&:pending?).select(&:platform?)
              optionals = @environment.stacks.select(&:pending?).select(&:optional?)
              stack = (platforms + optionals).first
              stack.client = cloud.client
              stack.cloud = cloud
              stack.status = :READY_FOR_CREATE
              stack.save!

              wait_for_finished(stack, TIMEOUT)

              update_environment stack.outputs if stack.platform?

              stack.status = :CREATE_COMPLETE
              stack.save!

              stack.client.post_process
            end

            finish_environment if @environment.reload

            Log.info "Created all stacks on environment(#{@environment.name}) on #{cloud.name}"
            break
          rescue => e
            Log.warn "Some error has occurred while creating stacks on environment(#{@environment.name}) on #{cloud.name}"
            Log.warn e.message
            Log.debug e.backtrace
            reset_stacks
          end
        end

        unless @environment.status == :CREATE_COMPLETE
          @environment.stacks.each do |stack|
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

        unless %i(CREATE_IN_PROGRESS CREATE_COMPLETE).include? status
          failed_events = stack.events.select { |event| %w(CREATE_FAILED).include?(event.resource_status) }
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

        next if status == :CREATE_IN_PROGRESS

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
      Log.info 'Platform stack has created.'
      @environment.ip_address = outputs['FrontendAddress']
      @environment.platform_outputs = outputs.except('FrontendAddress').to_json
      @environment.save!
    end

    def finish_environment
      @environment.event.sync_fire(:configure, configure_payload(@environment))
      @environment.event.sync_fire(:restore, application_payload(@environment))
      @environment.event.sync_fire(:deploy, application_payload(@environment)) unless @environment.deployments.empty?
      @environment.event.sync_fire(:spec)

      @environment.status = :CREATE_COMPLETE
      @environment.deployments.each do |deployment|
        deployment.update_attributes!(status: 'DEPLOY_COMPLETE')
      end
      @environment.save!
    end

    def reset_stacks
      Log.info 'Reset all stacks.'
      cloud = next_cloud(@environment.stacks.first.cloud)
      stacks = @environment.stacks.map(&:dup)

      @environment.status = :ERROR
      @environment.ip_address = nil
      @environment.platform_outputs = '{}'
      @environment.save!

      @environment.destroy_stacks

      return unless cloud

      Log.info "Recreate stacks on next cloud(#{cloud})"
      stacks.each do |stack|
        stack.cloud = cloud
      end
      @environment.stacks = stacks
    end

    private

    def configure_payload(environment)
      payload = {
        cloudconductor: {
          salt: OpenSSL::Digest::SHA256.hexdigest(environment.system.created_at.iso8601(6)),
          patterns: {
          }
        }
      }

      environment.stacks.created.each do |stack|
        payload[:cloudconductor][:patterns].deep_merge! stack.payload
      end

      payload
    end

    def application_payload(environment)
      return {} if environment.deployments.empty?

      environment.deployments.map(&:application_history).map(&:payload).inject(&:deep_merge)
    end

    def next_cloud(current_cloud)
      index = @clouds.index(current_cloud)
      @clouds[index + 1]
    end
  end
end
