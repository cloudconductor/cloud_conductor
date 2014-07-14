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
  module Converters
    class OpenStackConverter < Converter
      # rubocop:disable MethodLength
      def initialize
        super

        # Remove unimplemented properties from Instance
        properties = []
        properties << :DisableApiTermination
        properties << :KernelId
        properties << :Monitoring
        properties << :PlacementGroupName
        properties << :PrivateIpAddress
        properties << :RamDiskId
        properties << :SourceDestCheck
        properties << :Tenancy
        add_patch Patches::RemoveProperty.new 'AWS::EC2::Instance', properties

        # Remove unimplemented properties from LoadBalancer
        properties = []
        properties << :AppCookieStickinessPolicy
        properties << :Subnets
        properties << :SecurityGroups
        add_patch Patches::RemoveProperty.new 'AWS::ElasticLoadBalancing::LoadBalancer', properties

        add_patch Patches::RemoveRoute.new
        add_patch Patches::RemoveMultipleSubnet.new
        add_patch Patches::AddIAMUser.new
        add_patch Patches::AddIAMAccessKey.new
        add_patch Patches::AddCFNCredentials.new
      end
    end
  end
end
