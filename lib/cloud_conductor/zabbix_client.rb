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
  class ZabbixClient # rubocop: disable ClassLength
    def initialize
      config = CloudConductor::Config.zabbix

      @zabbix = ZabbixAPI.new config.url
      @zabbix.login config.user, config.password
    end

    def register(system)
      hostname = system.name
      hostgroup_id = register_hostgroup(hostname)
      host_id = register_host(hostgroup_id, system.domain)
      environment_id = system.primary_environment.id
      register_action("FailOver_#{hostname}", host_id, operation(environment_id, CloudConductor::Config.cloudconductor.url))
    rescue => e
      Log.error('Some error occurred while requesting to zabbix')
      Log.error(e)
      raise
    end

    private

    def register_hostgroup(name)
      result = @zabbix.hostgroup.get filter: { name: name }
      return result.first['groupid'].to_i unless result.empty?

      result = @zabbix.hostgroup.create name: name
      result['groupids'].first.to_i
    end

    def register_host(group_id, host) # rubocop: disable MethodLength
      result = @zabbix.host.get filter: { host: host }
      return result.first['hostid'].to_i unless result.empty?

      result = @zabbix.template.get filter: { name: CloudConductor::Config.zabbix.default_template_name }
      template_id = result.first['templateid'].to_i

      parameters = {
        host: host,
        interfaces: [
          {
            type: 1,
            main: 1,
            ip: '',
            dns: host,
            port: 10050,
            useip: 0
          }
        ],
        groups: [groupid: group_id],
        templates: [templateid: template_id]
      }

      result = @zabbix.host.create(parameters)
      result['hostids'].first.to_i
    end

    def register_action(name, host_id, operation)
      result = @zabbix.action.get filter: { name: name }
      if result.empty?
        insert_action(name, host_id, operation)
      else
        update_action(result.first['actionid'].to_i, host_id, operation)
      end
    end

    def insert_action(name, host_id, operation)
      params = {
        name: name,
        eventsource: 0,
        evaltype: 1, # AND
        status: 0, # enabled
        esc_period: 120,
        def_shortdata: '{TRIGGER.NAME}: {TRIGGER.STATUS}',
        def_longdata: '{TRIGGER.NAME}: {TRIGGER.STATUS}\r\nLast value: {ITEM.LASTVALUE}\r\n\r\n{TRIGGER.URL}',
        conditions: generate_conditions(host_id),
        operations: generate_operations(operation)
      }

      @zabbix.action.create(params)
    end

    def update_action(action_id, host_id, operation)
      params = {
        actionid: action_id,
        conditions: generate_conditions(host_id),
        operations: generate_operations(operation)
      }
      @zabbix.action.update(params)
    end

    def generate_conditions(host_id)
      [
        {
          conditiontype: 1, # host
          operator: 0, # equal
          value: host_id
        },
        {
          conditiontype: 5, # trigger value
          operator: 0, # equal
          value: 1
        }
      ]
    end

    def generate_operations(operation)
      [
        {
          operationtype: 1, # remote command
          opcommand_hst: {
            hostid: 0
          },
          opcommand: {
            type: 0, # custom script
            command: operation,
            execute_on: 1 # Zabbix server
          }
        }
      ]
    end

    def operation(environment_id, url)
      project = Environment.find(environment_id).system.project
      monitoring_account = project.accounts.where(email: "monitoring@#{project.name}.example.com").first

      parameter = { switch: true, auth_token: monitoring_account.authentication_token }
      %(curl -H "Content-Type:application/json" -X POST -d '#{parameter.to_json}' #{url}/environments/#{environment_id}/rebuild)
    end
  end
end
