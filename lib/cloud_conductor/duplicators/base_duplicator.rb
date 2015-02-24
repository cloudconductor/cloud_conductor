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
        return { source_name => @resources[source_name] } if been_copied? source_name, old_and_new_name_list

        new_name = "#{source_name}#{@options[:CopyNum]}"
        old_and_new_name_list[source_name] = new_name

        copied_resource = @resources[source_name].deep_dup
        roles = @options[:Role].split(',') + ['all']
        association_resources = collect_resources_associated_with(copied_resource).merge @resources.select(&contain?(source_name))

        association_resources.each do |name, resource|
          next unless roles.any? { |role| name.upcase.starts_with? role.upcase }
          duplicator = create_duplicator(resource['Type'])
          @resources.merge! duplicator.copy(name, old_and_new_name_list, options) if duplicator.need_to_copy?(resource)
        end

        { new_name => copy_post_processing(old_and_new_name_list, copied_resource) }
      end

      def need_to_copy?(resource)
        COPYABLE_RESOURCES.include? resource['Type']
      end

      private

      def been_copied?(source_name, old_and_new_name_list)
        return true if old_and_new_name_list.keys.include? source_name
        return true if old_and_new_name_list.values.include? source_name
        return true if @resources[source_name]['Metadata'] && @resources[source_name]['Metadata']['Copied']
        false
      end

      def add_metadata_for_check(copied_resource)
        copied_resource['Metadata'] = {} unless copied_resource['Metadata']
        copied_resource['Metadata']['Copied'] = true

        copied_resource
      end

      def copy_post_processing(old_and_new_name_list, copied_resource)
        copied_resource = change_for_association(old_and_new_name_list, copied_resource)
        copied_resource = change_for_properties(copied_resource)
        copied_resource = add_metadata_for_check(copied_resource)
        copied_resource
      end

      def create_duplicator(resource_type)
        duplicator_name = "#{resource_type.split('::').last}Duplicator"
        duplicator_name = 'BaseDuplicator' unless Duplicators.const_defined? duplicator_name
        Duplicators.const_get(duplicator_name).new(@resources, @options)
      end

      # rubocop:disable CyclomaticComplexity, PerceivedComplexity
      def contain_name_in_element?(source_name, element)
        return false unless element.respond_to?(:each)

        if element.is_a?(Hash)
          return true if source_name == element[:Ref]
          return true if element[:'Fn::GetAtt'] && source_name == element[:'Fn::GetAtt'].first
          return true if element[:DependsOn] && element[:DependsOn].include?(source_name)
        end

        element = element.values if element.respond_to?(:values)
        element.any? do |child_element|
          contain_name_in_element?(source_name, child_element)
        end
      end
      # rubocop:enable CyclomaticComplexity, PerceivedComplexity

      def contain?(source_name)
        ->(_, resource) { contain_name_in_element?(source_name, resource) }
      end

      def collect_names_associated_with(element)
        return [] unless element.respond_to?(:each)

        names = element.inject([]) do |s, child_element|
          s + collect_names_associated_with(child_element)
        end

        if element.is_a?(Hash)
          names << element['Ref'] if element.keys.first == 'Ref'
          names << element['Fn::GetAtt'].first if element.keys.first == 'Fn::GetAtt'
          names << element['DependsOn'] if element.keys.include?('DependsOn')
        end
        names.flatten
      end

      def collect_resources_associated_with(copied_resource)
        @resources.slice(*collect_names_associated_with(copied_resource).flatten.uniq)
      end

      def change_for_ref(old_name, new_name, element)
        return unless element.respond_to?(:each)

        element['Ref'] = new_name if element.is_a?(Hash) && element['Ref'] == old_name

        element = element.values if element.respond_to?(:values)
        element.each do |child_element|
          change_for_ref(old_name, new_name, child_element)
        end
      end

      # rubocop:disable CyclomaticComplexity
      def change_for_get_att(old_name, new_name, element)
        return unless element.respond_to?(:each)

        if element.is_a?(Hash) && element['Fn::GetAtt']
          new_get_att = element['Fn::GetAtt'].map do |get_att|
            (get_att == old_name && new_name) || get_att
          end
          element['Fn::GetAtt'] = new_get_att
          return
        end

        element = element.values if element.respond_to?(:values)
        element.each do |child_element|
          change_for_get_att(old_name, new_name, child_element)
        end
      end
      # rubocop:enable CyclomaticComplexity

      def change_for_depends_on(old_name, new_name, element)
        depends = element['DependsOn']

        return unless depends

        if depends.is_a? String
          element['DependsOn'] = new_name if depends == old_name
          return
        end

        new_depends = depends.map do |depend|
          (depend == old_name && new_name) || depend
        end
        element['DependsOn'] = new_depends
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
