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
class ZabbixApi
  module HostInterface
    module Type
      AGENT = 1
      SNMP = 2
      IPMI = 3
      JMX = 4
    end

    module Main
      NOT_DEFAULT = 0
      DEFAULT = 1
    end

    module UseIp
      DNS_NAME = 0
      IP_ADDRESS = 1
    end
  end

  module Action
    module Evaltype
      AND_OR = 0
      AND = 1
      OR = 2
    end

    module Status
      ENABLED = 0
      DISABLED = 1
    end

    module Condition
      module Type
        HOST_GROUP = 0
        HOST = 1
        TRIGGER = 2
        TRIGGER_NAME = 3
        TRIGGER_SEVERITY = 4
        TRIGGER_VALUE = 5
        TIME_PERIOD = 6
        HOST_IP = 7
        DISCOVERED_SERVICE_TYPE = 8
        DISCOVERED_SERVICE_PORT = 9
        DISCOVERY_STATUS = 10
        UPTIME_OR_DOWNTIME_DURATION = 11
        RECEIVED_VALUE = 12
        HOST_TEMPLATE = 13
        APPLICATION = 15
        MAINTENANCE_STATUS = 16
        NODE = 17
        DISCOVERY_RULE = 18
        DISCOVERY_CHECK = 19
        PROXY = 20
        DISCOVERY_OBJECT = 21
        HOST_NAME  = 22
        EVENT_TYPE  = 23
        HOST_METADATA = 24
      end

      module Operator
        EQUAL = 0
        NOT_EQUAL = 1
        LIKE = 2
        NOT_LIKE = 3
        IN = 4
        GREATER_THAN_OR_EQUAL = 5
        LESS_THAN_OR_EQUAL = 6
        NOT_IT = 7
      end
    end

    module Operation
      module Type
        SEND_MESSAGE = 0
        REMOTE_COMMAND = 1
        ADD_HOST = 2
        REMOVE_HOST = 3
        ADD_TO_HOST_GROUP = 4
        REMOVE_FROM_HOST_GROUP = 5
        LINK_TO_TEMPLATE = 6
        UNLINK_FROM_TEMPLATE = 7
        ENABLE_HOST = 8
        DISABLE_HOST = 9
      end

      module Command
        module Type
          CUSTOM_SCRIPT = 0
          IPMI = 1
          SSH = 2
          TELNET = 3
          GLOBAL_SCRIPT = 4
        end

        module ExecuteOn
          ZABBIX_AGENT = 0
          ZABBIX_SERVER = 1
        end
      end
    end
  end
end
