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
    class RenamePrimaryPrivateIpAddress < Patch
      def initialize
      end

      def apply(template, _parameters)
        template = template.deep_dup

        rename_primary_private_ip_address(template)

        template
      end

      def rename_primary_private_ip_address(current)
        current.each do |value|
          if current.is_a?(Hash)
            key = value.first
            value = value.last
          end

          next unless value.respond_to?(:each)

          if key == 'Fn::GetAtt' && value.last == 'PrimaryPrivateIpAddress'
            value[value.size - 1] = 'PrivateIpAddress'
          end

          rename_primary_private_ip_address value
        end
      end
    end
  end
end
