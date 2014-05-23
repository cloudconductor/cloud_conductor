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
  module Adapters
    class OpenStackAdapter < AbstractAdapter
      TYPE = :openstack
      def initialize
      end

      def create_stack(name, template, parameters, options = {})
        options = options.with_indifferent_access
        orc = ::Fog::Orchestration.new(
          provider: :OpenStack,
          openstack_auth_url: options[:entry_point].to_s + 'v2.0/tokens',
          openstack_api_key: options[:secret],
          openstack_username: options[:key],
          openstack_tenant: options[:tenant_id]
        )
        stack_params = {
          template: template,
          parameters: JSON.parse(parameters)
        }
        orc.create_stack name, stack_params
      end

      def get_stack_status(name, options = {})
        options = options.with_indifferent_access
        orc = ::Fog::Orchestration.new(
          provider: :OpenStack,
          openstack_auth_url: options[:entry_point].to_s + 'v2.0/tokens',
          openstack_api_key: options[:secret],
          openstack_username: options[:key],
          openstack_tenant: options[:tenant_id]
        )
        body = (orc.list_stacks)[:body].with_indifferent_access
        target_stack = body[:stacks].find { |stack| stack[:stack_name] == name }
        target_stack[:stack_status]
      end
    end
  end
end
