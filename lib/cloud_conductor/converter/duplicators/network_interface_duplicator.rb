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
  class Converter
    module Duplicators
      class NetworkInterfaceDuplicator < BaseDuplicator
        include DuplicatorUtils

        def replace_copied_properties(resource)
          subnet = @resources[resource['Properties']['SubnetId']['Ref']]
          cidr = NetAddr::CIDR.create(subnet['Properties']['CidrBlock'])
          allocatable_addresses = get_allocatable_addresses(@resources, cidr)

          properties = resource['Properties']
          if properties['PrivateIpAddress']
            properties['PrivateIpAddress'] = allocatable_addresses.first
          elsif properties['PrivateIpAddresses']
            properties['PrivateIpAddresses'].each do |ip_address|
              ip_address['PrivateIpAddress'] = allocatable_addresses.shift
            end
          end

          resource
        end
      end
    end
  end
end
