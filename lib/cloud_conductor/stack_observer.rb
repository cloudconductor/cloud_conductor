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
    def check_stacks
      System.in_progress.each do |system|
        Log.info "Check and update stack with #{system.name}"
        next if system.status != :CREATE_COMPLETE

        Log.debug '  Status is CREATE_COMPLETE'

        outputs = system.outputs
        next if outputs['EIP'].nil?

        ip_address = outputs['EIP']
        Log.debug "  Outputs has EIP(#{ip_address})"

        `curl http://#{ip_address}/`

        next if $CHILD_STATUS.exitstatus != 0

        Log.info "  Instance is running on #{ip_address}, CloudConductor will register host to zabbix."

        system.monitoring_host = ip_address
        system.save!
      end
    end
  end
end
