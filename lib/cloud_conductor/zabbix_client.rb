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
  class ZabbixClient
    def register(system)
      cc_api_url = CloudConductor::Config.cloudconductor.url
      zbx = ZabbixApi.connect CloudConductor::Config.zabbix.configuration

      hostgroup_id = zbx.hostgroups.create_or_update name: system.name
      template_id = zbx.templates.get_id host: 'Template App HTTP Service'

      host_id = add_host_zabbix zbx, system.monitoring_host, hostgroup_id, template_id
      add_action_zabbix zbx, host_id, cc_api_url, system.id
    end

    private

    def add_host_zabbix(zbx, target_host, hostgroup_id, template_id)
      params = {
        host: target_host,
        interfaces: [
          {
            type: 1,
            main: 1,
            ip: '',
            dns: target_host,
            port: 10_050,
            useip: 0
          }
        ],
        groups: [groupid: hostgroup_id],
        templates: [templateid: template_id]
      }
      zbx.hosts.create_or_update params
    end

    def check_if_action_exists_zabbix(zbx, action_name)
      params = {
        method: 'action.exists',
        params: {
          name: action_name
        }
      }
      zbx.client.api_request(params)
    end

    def create_action_command_zabbix(cc_api_url, system_id)
      "curl -H \"Content-Type:application/json\" -X POST -d '{\"system_id\": \"#{system_id}\"}' #{cc_api_url}"
    end

    # rubocop: disable MethodLength
    def add_action_zabbix(zbx, host_id, cc_api_url, system_id)
      action_name = 'FailOver'
      action_exists = check_if_action_exists_zabbix zbx, action_name

      return if action_exists

      params = {
        method: 'action.create',
        params: {
          name: action_name,
          eventsource: 0,
          evaltype: 1,
          status: 0,
          esc_period: 120,
          def_shortdata: '{TRIGGER.NAME}: {TRIGGER.STATUS}',
          def_longdata: '{TRIGGER.NAME}: {TRIGGER.STATUS}\r\nLast value: {ITEM.LASTVALUE}\r\n\r\n{TRIGGER.URL}',
          conditions: [
            {
              conditiontype: 1,
              operator: 0,
              value: host_id
            },
            {
              conditiontype: 5,
              operator: 0,
              value: 1
            }
          ],
          operations: [
            {
              operationtype: 1,
              opcommand_hst: {
                hostid: 0
              },
              opcommand: {
                type: 0,
                command: create_action_command_zabbix(cc_api_url, system_id),
                execute_on: '1'
              }
            }
          ]
        }
      }
      zbx.client.api_request params
    end
    # rubocop: enable MethodLength
  end
end
