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
  module Duplicators
    class BaseDuplicator # rubocop:disable ClassLength
      COPYABLE_RESOURCES = [
        'AWS::EC2::Instance',
        'AWS::EC2::NetworkInterface',
        'AWS::EC2::Subnet',
        'AWS::EC2::SubnetRouteTableAssociation',
        'AWS::EC2::EIP',
        'AWS::EC2::EIPAssociation',
        'AWS::EC2::Volume',
        'AWS::EC2::VolumeAttachment',
        'AWS::CloudFormation::WaitConditionHandle',
        'AWS::CloudFormation::WaitCondition'
      ]

      def initialize(resources, options)
        @resources = resources
        @options = options
      end

      def post(resource)
        resource
      end

      # rubocop:disable CyclomaticComplexity, PerceivedComplexity
      def copy(source_name, copy_num, name_map = {}, options = {})
        new_name = "#{source_name}#{copy_num}"
        return if name_map.keys.include? source_name
        return if name_map.values.include? source_name
        return if @resources[source_name]['Metadata'] && @resources[source_name]['Metadata']['Copied']

        name_map[source_name] = new_name
        copied_resource = @resources[source_name].deep_dup

        collect(copied_resource).each do |name, resource|
          duplicator = create_duplicator(resource['Type'])

          duplicator.copy(name, copy_num, name_map, options) if duplicator.copy?(resource)
        end

        change(copied_resource, name_map)
        changed_resource = post(copied_resource)
        changed_resource['Metadata'] = {} unless changed_resource['Metadata']
        changed_resource['Metadata']['Copied'] = 'true'
        @resources.merge!(new_name => changed_resource)

        @resources.select(&contain?(source_name)).each do |name, resource|
          duplicator = create_duplicator(resource['Type'])

          duplicator.copy(name, copy_num, name_map, options) if duplicator.copy?(resource)
        end
      end

      def copy?(resource)
        COPYABLE_RESOURCES.include? resource['Type']
      end

      private

      def create_duplicator(type)
        duplicator_name = "#{type.split('::').last}Duplicator"
        duplicator_name = 'BaseDuplicator' unless Duplicators.const_defined? duplicator_name
        Duplicators.const_get(duplicator_name).new(@resources, @options)
      end

      def contain_ref(obj, name)
        return false unless obj.respond_to?(:each)

        return true if obj.is_a?(Hash) && name == obj[:Ref]

        obj = obj.values if obj.respond_to?(:values)
        obj.any? do |node|
          contain_ref(node, name)
        end
      end

      def contain_att(obj, name)
        return false unless obj.respond_to?(:each)

        if obj.is_a?(Hash) && obj[:'Fn::GetAtt']
          return true if name == obj[:'Fn::GetAtt'].first
        end

        obj = obj.values if obj.respond_to?(:values)
        obj.any? do |node|
          contain_att(node, name)
        end
      end

      def contain_depends(resource, name)
        resource[:DependsOn] && resource[:DependsOn].include?(name)
      end

      def contain?(name)
        lambda do |_, resource|
          return true if contain_ref(resource, name)
          return true if contain_att(resource, name)
          return true if contain_depends(resource, name)
          false
        end
      end

      def collect_ref(obj)
        return [] unless obj.respond_to?(:each)

        names = obj.inject([]) do |s, child|
          s + collect_ref(child)
        end

        names << obj['Ref'] if obj.is_a?(Hash) && obj.keys.first == 'Ref'
        names
      end

      def collect_att(obj)
        return [] unless obj.respond_to?(:each)

        names = obj.inject([]) do |s, child|
          s + collect_att(child)
        end

        names << obj['Fn::GetAtt'].first if obj.is_a?(Hash) && obj.keys.first == 'Fn::GetAtt'
        names
      end

      def collect_depends(obj)
        return [] unless obj.respond_to?(:each)

        names = obj.inject([]) do |s, child|
          s + collect_depends(child)
        end

        names << obj['DependsOn'] if obj.is_a?(Hash) && obj.keys.include?('DependsOn')
        names.flatten
      end

      def collect(resource)
        names = []
        names << collect_ref(resource)
        names << collect_att(resource)
        names << collect_depends(resource)
        @resources.slice(*names.flatten.uniq)
      end

      def change_ref(obj, old_key, new_key)
        return false unless obj.respond_to?(:each)

        obj['Ref'] = new_key if obj.is_a?(Hash) && obj['Ref'] == old_key

        obj = obj.values if obj.respond_to?(:values)
        obj.any? do |node|
          change_ref(node, old_key, new_key)
        end
      end

      def change_att(obj, old_key, new_key)
        return false unless obj.respond_to?(:each)

        if obj.is_a?(Hash) && obj['Fn::GetAtt']
          new_get_att = obj['Fn::GetAtt'].map do |get_att|
            (get_att == old_key && new_key) || get_att
          end
          obj['Fn::GetAtt'] = new_get_att
          return true
        end

        obj = obj.values if obj.respond_to?(:values)
        obj.any? do |node|
          change_att(node, old_key, new_key)
        end
      end

      def change_depends(resource, old_key, new_key)
        depends = resource['DependsOn']

        return unless depends

        if depends.is_a? String
          resource['DependsOn'] = new_key if depends == old_key
          return
        end

        new_depends = depends.map do |depend|
          (depend == old_key && new_key) || depend
        end
        resource['DependsOn'] = new_depends
      end

      def change(resource, name_map)
        name_map.each do |old_key, new_key|
          change_ref(resource, old_key, new_key)
          change_att(resource, old_key, new_key)
          change_depends(resource, old_key, new_key)
        end
      end
    end
  end
end
