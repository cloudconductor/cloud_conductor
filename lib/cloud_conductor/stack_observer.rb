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
  class StackObserver
    def update
      Stack.in_progress.each do |stack|
        Log.info "Check and update stack with #{stack.name}"
        next if stack.status != :CREATE_COMPLETE

        Log.debug '  Status is CREATE_COMPLETE'

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

        stack.status = :CREATE_COMPLETE
        stack.save!

        update_system stack.system, outputs
      end
    end

    private

    def update_system(system, outputs)
      if outputs
        Log.info '  Instance is running, CloudConductor will register host to zabbix/DNS.'
        system.ip_address = outputs['FrontendAddress']
        system.monitoring_host = system.domain
        system.template_parameters = outputs.to_json
        system.save!
      end

      stack = system.stacks.find(&:pending?)
      if stack
        stack.status = :READY
        stack.save!
      else
        finish_system system
      end
    end

    def finish_system(system)
      payload = {
        cloudconductor: {
          patterns: {
          }
        }
      }

      system.stacks.created.each do |stack|
        payload[:cloudconductor][:patterns].deep_merge! stack.payload
      end
      system.serf.call('event', 'configure', payload)

      sleep 3
      system.send_application_payload

      sleep 3
      system.serf.call('event', 'restore', {})

      sleep 3
      system.deploy_applications
    end
  end
end
