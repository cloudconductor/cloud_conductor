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
    class InstanceDuplicator < BaseDuplicator
      include DuplicatorUtils

      def change_properties(resource)
        return resource unless resource['Properties']['NetworkInterfaces']

        resource['Properties']['NetworkInterfaces'].each do |network_interface|
          next if network_interface['NetworkInterfaceId']

          subnet = @resources[network_interface['SubnetId']['Ref']]
          cidr = NetAddr::CIDR.create(subnet['Properties']['CidrBlock'])
          allocatable_addresses = get_allocatable_addresses(@resources, cidr)

          if network_interface['PrivateIpAddress']
            network_interface['PrivateIpAddress'] = allocatable_addresses.first
          elsif network_interface['PrivateIpAddresses']
            network_interface['PrivateIpAddresses'].each do |ip_address|
              ip_address['PrivateIpAddress'] = allocatable_addresses.shift
            end
          end
        end

        resource
      end
    end
  end
end
