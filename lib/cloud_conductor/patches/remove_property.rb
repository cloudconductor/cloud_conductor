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
    class RemoveProperty < Patch
      include PatchUtils

      def initialize(type, properties)
        @type = type
        @properties = [properties].flatten.map do |property|
          next [property] if property.is_a? Symbol
          property.split('.').map(&:to_sym)
        end
      end

      def ensure(template, _parameters)
        template[:Resources] ||= {}
        template
      end

      def apply(template, _parameters)
        template = template.deep_dup

        resources = template[:Resources].select(&type?(@type))
        resources.values.each do |resource|
          @properties.each do |keys|
            remove_properties resource[:Properties], keys
          end
        end
        template
      end

      def remove_properties(current, keys)
        if current.is_a? Array
          current.each do |node|
            remove_properties node, keys
          end
          return
        end

        return unless !current.nil? && current.respond_to?(:except)

        current.except! keys.first if keys.size == 1

        remove_properties current[keys.first], keys.slice(1..-1)
      end
    end
  end
end
