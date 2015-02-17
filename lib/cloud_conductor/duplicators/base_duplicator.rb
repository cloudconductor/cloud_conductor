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

      def change_for_properties(copied_resource)
        copied_resource
      end

      # old_and_new_name_list = { old_name: new_name, ... }
      def copy(source_name, old_and_new_name_list = {}, options = {})
        return if check_whether_copied source_name, old_and_new_name_list

        new_name = "#{source_name}#{@options[:CopyNum]}"
        old_and_new_name_list[source_name] = new_name

        copied_resource = @resources[source_name].deep_dup

        collect_association(copied_resource).each do |name, resource|
          duplicator = create_duplicator(resource['Type'])
          duplicator.copy(name, old_and_new_name_list, options) if duplicator.copy?(resource)
        end

        copied_resource = change_for_association(old_and_new_name_list, copied_resource)
        copied_resource = change_for_properties(copied_resource)
        copied_resource = add_metadata_for_check(copied_resource)

        @resources.merge!(new_name => copied_resource)

        @resources.select(&contain_association?(source_name)).each do |name, resource|
          duplicator = create_duplicator(resource['Type'])
          duplicator.copy(name, old_and_new_name_list, options) if duplicator.copy?(resource)
        end
      end

      def copy?(resource)
        COPYABLE_RESOURCES.include? resource['Type']
      end

      private

      def check_whether_copied(source_name, old_and_new_name_list)
        return true if old_and_new_name_list.keys.include? source_name
        return true if old_and_new_name_list.values.include? source_name
        return true if @resources[source_name]['Metadata'] && @resources[source_name]['Metadata']['Copied']
        false
      end

      def add_metadata_for_check(copied_resource)
        copied_resource['Metadata'] = {} unless copied_resource['Metadata']
        copied_resource['Metadata']['Copied'] = 'true'

        copied_resource
      end

      def create_duplicator(resource_type)
        duplicator_name = "#{resource_type.split('::').last}Duplicator"
        duplicator_name = 'BaseDuplicator' unless Duplicators.const_defined? duplicator_name
        Duplicators.const_get(duplicator_name).new(@resources, @options)
      end

      def contain_ref(source_name, resource)
        return false unless resource.respond_to?(:each)

        return true if resource.is_a?(Hash) && source_name == resource[:Ref]

        resource = resource.values if resource.respond_to?(:values)
        resource.any? do |child_resource|
          contain_ref(source_name, child_resource)
        end
      end

      def contain_get_att(source_name, resource)
        return false unless resource.respond_to?(:each)

        if resource.is_a?(Hash) && resource[:'Fn::GetAtt']
          return true if source_name == resource[:'Fn::GetAtt'].first
        end

        resource = resource.values if resource.respond_to?(:values)
        resource.any? do |child_resource|
          contain_get_att(source_name, child_resource)
        end
      end

      def contain_depends_on(source_name, resource)
        resource[:DependsOn] && resource[:DependsOn].include?(source_name)
      end

      def contain_association?(source_name)
        lambda do |_, resource|
          return true if contain_ref(source_name, resource)
          return true if contain_get_att(source_name, resource)
          return true if contain_depends_on(source_name, resource)
          false
        end
      end

      def collect_ref(resource)
        return [] unless resource.respond_to?(:each)

        names = resource.inject([]) do |s, child_resource|
          s + collect_ref(child_resource)
        end

        names << resource['Ref'] if resource.is_a?(Hash) && resource.keys.first == 'Ref'
        names
      end

      def collect_get_att(resource)
        return [] unless resource.respond_to?(:each)

        names = resource.inject([]) do |s, child_resource|
          s + collect_get_att(child_resource)
        end

        names << resource['Fn::GetAtt'].first if resource.is_a?(Hash) && resource.keys.first == 'Fn::GetAtt'
        names
      end

      def collect_depends_on(resource)
        return [] unless resource.respond_to?(:each)

        names = resource.inject([]) do |s, child_resource|
          s + collect_depends_on(child_resource)
        end

        names << resource['DependsOn'] if resource.is_a?(Hash) && resource.keys.include?('DependsOn')
        names.flatten
      end

      def collect_association(copied_resource)
        names = []
        names << collect_ref(copied_resource)
        names << collect_get_att(copied_resource)
        names << collect_depends_on(copied_resource)
        @resources.slice(*names.flatten.uniq)
      end

      def change_for_ref(old_name, new_name, resource)
        return unless resource.respond_to?(:each)

        resource['Ref'] = new_name if resource.is_a?(Hash) && resource['Ref'] == old_name

        resource = resource.values if resource.respond_to?(:values)
        resource.any? do |child_resource|
          change_for_ref(old_name, new_name, child_resource)
        end
      end

      # rubocop:disable CyclomaticComplexity
      def change_for_get_att(old_name, new_name, resource)
        return unless resource.respond_to?(:each)

        if resource.is_a?(Hash) && resource['Fn::GetAtt']
          new_get_att = resource['Fn::GetAtt'].map do |get_att|
            (get_att == old_name && new_name) || get_att
          end
          resource['Fn::GetAtt'] = new_get_att
          return
        end

        resource = resource.values if resource.respond_to?(:values)
        resource.any? do |child_resource|
          change_for_get_att(old_name, new_name, child_resource)
        end
      end
      # rubocop:enable CyclomaticComplexity

      def change_for_depends_on(old_name, new_name, resource)
        depends = resource['DependsOn']

        return unless depends

        if depends.is_a? String
          resource['DependsOn'] = new_name if depends == old_name
          return
        end

        new_depends = depends.map do |depend|
          (depend == old_name && new_name) || depend
        end
        resource['DependsOn'] = new_depends
      end

      def change_for_association(old_and_new_name_list, copied_resource)
        old_and_new_name_list.each do |old_name, new_name|
          change_for_ref(old_name, new_name, copied_resource)
          change_for_get_att(old_name, new_name, copied_resource)
          change_for_depends_on(old_name, new_name, copied_resource)
        end

        copied_resource
      end
    end
  end
end
