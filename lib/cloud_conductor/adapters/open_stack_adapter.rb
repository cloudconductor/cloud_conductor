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
require 'fog/openstack/models/orchestration/stack'

module CloudConductor
  module Adapters
    class OpenStackAdapter < AbstractAdapter # rubocop:disable ClassLength
      TYPE = :openstack
      def initialize
        @post_processes = []
      end

      def heat(options)
        ::Fog::Orchestration.new(
          provider: :OpenStack,
          openstack_auth_url: options[:entry_point].to_s + 'v2.0/tokens',
          openstack_api_key: options[:secret],
          openstack_username: options[:key],
          openstack_tenant: options[:tenant_name]
        )
      end

      def nova(options)
        ::Fog::Compute.new(
          provider: :OpenStack,
          openstack_auth_url: options[:entry_point].to_s + 'v2.0/tokens',
          openstack_api_key: options[:secret],
          openstack_username: options[:key],
          openstack_tenant: options[:tenant_name]
        )
      end

      def create_stack(name, template, parameters, options = {})
        @post_processes << lambda do
          add_security_rules(name, template, parameters, options)
        end

        converter = CfnConverter.create_converter(:heat)
        converted_template = converter.convert(template, parameters)

        options = options.with_indifferent_access
        stack_params = {
          stack_name: name,
          template: converted_template,
          parameters: parameters
        }
        heat(options).create_stack stack_params
      end

      def update_stack(name, template, parameters, options = {})
        converter = CfnConverter.create_converter(:heat)
        converted_template = converter.convert(template, parameters)

        options = options.with_indifferent_access
        id = get_stack_id(name, options)
        stack = ::Fog::Orchestration::OpenStack::Stack.new(id: id, stack_name: name)
        stack_params = {
          template: converted_template,
          parameters: parameters
        }
        Log.info "Start updating #{name} stack"
        heat(options).update_stack stack, stack_params
      end

      def get_stack_id(name, options = {})
        options = options.with_indifferent_access
        body = (heat(options).list_stack_data)[:body].with_indifferent_access
        target_stack = body[:stacks].find { |stack| stack[:stack_name] == name }
        target_stack[:id]
      end

      def get_stack_status(name, options = {})
        options = options.with_indifferent_access
        body = (heat(options).list_stack_data)[:body].with_indifferent_access
        target_stack = body[:stacks].find { |stack| stack[:stack_name] == name }
        target_stack[:stack_status].to_sym
      end

      def get_outputs(name, options = {})
        options = options.with_indifferent_access
        body = (heat(options).list_stack_data)[:body].with_indifferent_access
        target_stack = body[:stacks].find { |stack| stack[:stack_name] == name }
        target_link = target_stack[:links].find { |link| link[:rel] == 'self' }
        url = URI.parse "#{target_link[:href]}"
        request = Net::HTTP::Get.new url.path
        request.content_type = 'application/json'
        request.add_field 'X-Auth-Token', heat(options).auth_token
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

      def get_availability_zones(options = {})
        options = options.with_indifferent_access
        nova(options).hosts.map(&:zone).uniq
      end

      def add_security_rules(name, template, parameters, options = {})
        options = options.with_indifferent_access
        security_group_ingresses = JSON.parse(template)['Resources'].select do |_, resource|
          resource['Type'] == 'AWS::EC2::SecurityGroupIngress'
        end

        security_group_ingresses.each do |_, security_group_ingress|
          properties = security_group_ingress['Properties'].with_indifferent_access
          add_security_rule(nova(options), name, properties, parameters)
        end
      rescue => e
        Log.error 'Failed to add security rule.'
        Log.error e
      end

      def add_security_rule(nova, name, properties, parameters)
        rule = {
          ip_protocol: properties[:IpProtocol],
          from_port: properties[:FromPort],
          to_port: properties[:ToPort]
        }.with_indifferent_access

        if properties[:GroupId][:Ref] == 'SharedSecurityGroup' && parameters[:SharedSecurityGroup]
          rule[:parent_group_id] = parameters[:SharedSecurityGroup]
        else
          parent_group_name = "#{name}-#{properties[:GroupId][:Ref]}"
          rule[:parent_group_id] = get_security_group_id(nova, parent_group_name)
        end

        if properties[:SourceSecurityGroupId]
          security_group_name = "#{name}-#{properties[:SourceSecurityGroupId][:Ref]}"
          security_group_id = get_security_group_id(nova, security_group_name)
          return if security_group_id.nil?
          rule[:group] = security_group_id
        else
          rule[:ip_range] = { cidr: properties[:CidrIp] }
        end

        nova.security_group_rules.new(rule).save
      end

      def get_security_group_id(nova, security_group_name)
        target_security_group = nova.security_groups.all.find do |security_group|
          security_group.name.sub(/-[0-9a-zA-Z]{12}$/, '') == security_group_name
        end
        target_security_group.id if target_security_group
      end

      def destroy_stack(name, options = {})
        options = options.with_indifferent_access
        stack = heat(options).stacks.find { |stack| stack.stack_name == name }
        unless stack
          Log.warn("Target stack was already deleted( stack_name = #{name})")
          return
        end
        stack.delete
      end

      def destroy_image(name, options = {})
        options = options.with_indifferent_access
        image = nova(options).images.get(name)

        image.destroy if image
      end

      def post_process
        @post_processes.each(&:call)
      end
    end
  end
end
