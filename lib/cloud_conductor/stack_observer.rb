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
      System.in_progress.each do |system|
        Log.info "Check and update stack with #{system.name}"
        next if system.status != :CREATE_COMPLETE

        Log.debug '  Status is CREATE_COMPLETE'

        outputs = system.outputs
        next if outputs['FrontendAddress'].nil?

        ip_address = outputs['FrontendAddress']
        Log.debug "  Outputs has FrontendAddress(#{ip_address})"

        serf = Serf::Client.new host: ip_address
        status, _results = serf.call('info')
        next unless status.success?

        Log.info "  Instance is running on #{ip_address}, CloudConductor will register host to zabbix."
        update_system system, ip_address
      end
    end

    private

    def update_system(system, ip_address)
      system.ip_address = ip_address
      system.monitoring_host = system.domain
      system.save!

      payload = {}
      payload[:parameters] = JSON.parse(system.parameters)
      system.serf.call('event', 'configure', payload)
    end
  end
end
