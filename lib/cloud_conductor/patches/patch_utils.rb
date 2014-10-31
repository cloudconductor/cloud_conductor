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
  module Patches
    module PatchUtils
      def type?(type)
        ->(_, resource) { resource[:Type] == type }
      end

      def remove_resource(template, *resource_names)
        template = template.deep_dup

        template[:Resources].except!(*resource_names)

        # remove from array properties
        remove_from_array(nil, template, resource_names)

        # remove from DependsOn
        template[:Resources].each do |_key, resource|
          resource[:DependsOn] = [resource[:DependsOn]].flatten - resource_names if resource[:DependsOn]
        end

        # remove output with deleted resource
        (template[:Outputs] || {}).reject! do |_key, output|
          contains_ref(output, resource_names) || contains_att(output, resource_names)
        end

        # remove dependency resource with deleted resource
        template[:Resources].reject! do |_key, output|
          contains_ref(output, resource_names) || contains_att(output, resource_names)
        end

        template
      end

      def contains_ref(obj, names)
        return false unless obj.respond_to?(:each)

        return true if obj.is_a?(Hash) && names.include?(obj[:Ref])

        obj = obj.values if obj.respond_to?(:values)
        obj.any? do |node|
          contains_ref(node, names)
        end
      end

      def contains_att(obj, names)
        return false unless obj.respond_to?(:each)

        if obj.is_a?(Hash) && obj[:'Fn::GetAtt']
          return true if names.include?(obj[:'Fn::GetAtt'].first)
        end

        obj = obj.values if obj.respond_to?(:values)
        obj.any? do |node|
          contains_att(node, names)
        end
      end

      def remove_from_array(parent, obj, names)
        return unless obj.respond_to?(:each)

        if obj.is_a? Hash
          if names.include?(obj[:Ref]) || obj[:'Fn::GetAtt'] && names.include?(obj[:'Fn::GetAtt'].first)
            parent.delete obj
          end
          obj = obj.values
        end

        obj.each do |node|
          remove_from_array(obj, node, names)
        end
      end
    end
  end
end
