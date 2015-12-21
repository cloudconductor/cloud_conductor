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
require 'mixlib/config'

module CloudConductor
  class Config
    extend Mixlib::Config

    default :application_log_path, 'log/conductor_production.log'
    default :access_log_path, 'log/conductor_access.log'

    config_context :cloudconductor do
    end
    config_context :cloudconductor_init do
    end
    config_context :packer do
      default :path, '/opt/packer/packer'
      default :aws_instance_type, 'c3.large'
    end
    config_context :dns do
    end
    config_context :zabbix do
    end
    config_context :consul do
      config_context :options do
        config_context :ssl_options do
        end
      end
    end
    config_context :event do
      default :timeout, 1800
    end
    config_context :system_build do
      default :timeout, 1800
    end
    config_context :audit do
      default :method, ['PUT', 'POST', 'DELETE']
    end
  end
end
