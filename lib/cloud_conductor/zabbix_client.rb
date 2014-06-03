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
  # rubocop: disable ClassLength
  class ZabbixClient
    def register(system)
      cc_api_url = CloudConductor::Config.cloudconductor.url
      zbx = ZabbixApi.connect CloudConductor::Config.zabbix.configuration

      hostgroup_id = zbx.hostgroups.create_or_update name: system.name
      template_id = zbx.templates.get_id host: 'Template App HTTP Service'

      host_id = add_host_zabbix zbx, system.monitoring_host, hostgroup_id, template_id
      add_action_zabbix(
        zbx: zbx,
        host_id: host_id,
        cc_api_url: cc_api_url,
        system_id: system.id,
        system_name: system.name,
        target_host: system.monitoring_host
      )
    end

    private

    def get_hostgroups_host_belongs_to_zabbix(zbx, host_id)
      params = {
        method: 'host.get',
        params: {
          selectGroups: 'extend',
          output: 'extend',
          filter: {
            hostid: [
              host_id
            ]
          }
        }
      }
      result = (zbx.client.api_request params).find { |host| host.with_indifferent_access[:hostid] == host_id }
      result.with_indifferent_access[:groups]
    end

    def update_host_zabbix(zbx, host_id, hostgroup_id)
      params = {
        method: 'host.update',
        params: {
          hostid: host_id,
          groups: [
            { groupid: hostgroup_id }
          ]
        }
      }
      prev_hostgroups = get_hostgroups_host_belongs_to_zabbix zbx, host_id
      prev_hostgroups.each { |hostgroup| params[:params][:groups] << { groupid: hostgroup[:groupid] } }
      zbx.client.api_request(params)
      host_id
    end

    def get_host_id_zabbix(zbx, target_host)
      result = zbx.hosts.get(name: target_host).find { |host| host.with_indifferent_access[:host] == target_host }
      result ? result.with_indifferent_access[:hostid] : nil
    end

    def add_host_zabbix(zbx, target_host, hostgroup_id, template_id)
      host_id = get_host_id_zabbix(zbx, target_host)
      return update_host_zabbix(zbx, host_id, hostgroup_id) if host_id
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
    def add_action_zabbix(parameters)
      zbx = parameters[:zbx]
      host_id = parameters[:host_id]
      cc_api_url = parameters[:cc_api_url]
      system_id = parameters[:system_id]
      system_name = parameters[:system_name]
      target_host = parameters[:target_host]
      action_name = "FailOver_#{system_name}_#{target_host}"
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
  # rubocop: enable ClassLength
end
