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

      def create_orchestration(options)
        ::Fog::Orchestration.new(
          provider: :OpenStack,
          openstack_auth_url: options[:entry_point].to_s + 'v2.0/tokens',
          openstack_api_key: options[:secret],
          openstack_username: options[:key],
          openstack_tenant: options[:tenant_name]
        )
      end

      def create_stack(name, template, parameters, options = {})
        converter = Converters::OpenStackConverter.new
        template = converter.convert(template, parameters)

        options = options.with_indifferent_access
        orc = create_orchestration options
        stack_params = {
          template: template,
          parameters: parameters
        }
        orc.create_stack name, stack_params
      end

      def get_stack_status(name, options = {})
        options = options.with_indifferent_access
        orc = create_orchestration options
        body = (orc.list_stacks)[:body].with_indifferent_access
        target_stack = body[:stacks].find { |stack| stack[:stack_name] == name }
        target_stack[:stack_status].to_sym
      end

      def get_outputs(name, options = {})
        options = options.with_indifferent_access
        orc = create_orchestration options
        body = (orc.list_stacks)[:body].with_indifferent_access
        target_stack = body[:stacks].find { |stack| stack[:stack_name] == name }
        target_link = target_stack[:links].find { |link| link[:rel] == 'self' }
        url = URI.parse "#{target_link[:href]}"
        request = Net::HTTP::Get.new url.path
        request.content_type = 'application/json'
        request.add_field 'X-Auth-Token', orc.auth_token
        response = Net::HTTP.start url.host, url.port do |http|
          http.request request
        end
        response = (JSON.parse response.body).with_indifferent_access
        target_stack = response[:stack]
        outputs = {}
        target_stack[:outputs].each do |output|
          outputs[output[:output_key]] = output[:output_value]
        end

        outputs
      end

      def destroy_stack(name, options = {})
        options = options.with_indifferent_access
        orc = create_orchestration options
        body = (orc.list_stacks)[:body].with_indifferent_access
        target_stack = body[:stacks].find { |stack| stack[:stack_name] == name }
        if target_stack.nil?
          Log.warn("Target stack was already deleted( stack_name = #{name})")
          return
        end
        stack_id = target_stack[:id].to_sym
        orc.delete_stack name, stack_id
      end
    end
  end
end
