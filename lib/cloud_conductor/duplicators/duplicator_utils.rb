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
    module DuplicatorUtils
      def type?(type)
        ->(_, resource) { resource[:Type] == type }
      end

      def get_allocatable_addresses(resources, cidr)
        instances = resources.select(&type?('AWS::EC2::Instance'))
        nics = resources.select(&type?('AWS::EC2::NetworkInterface'))

        used_addresses = [cidr.network, cidr.broadcast]
        used_addresses += get_ip_address_for_instances(instances)
        used_addresses += get_ip_address_for_network_interface(nics)
        cidr.enumerate - used_addresses.uniq.compact
      end

      def get_ip_address_for_instances(instances)
        instances.inject([]) do |addresses, instance|
          properties = instance.last['Properties']
          addresses << properties['PrivateIpAddress'] if properties['PrivateIpAddress']

          (properties['NetworkInterfaces'] || []).each_with_object(addresses) do |network_interface, nic_addresses|
            nic_addresses << get_private_ip_address(network_interface) unless network_interface['NetworkInterfaceId']
          end.flatten
        end
      end

      def get_ip_address_for_network_interface(nics)
        nics.inject([]) do |addresses, nic|
          addresses + get_private_ip_address(nic.last['Properties'])
        end
      end

      def get_private_ip_address(nic)
        if nic['PrivateIpAddress']
          [nic['PrivateIpAddress']]
        elsif nic['PrivateIpAddresses']
          nic['PrivateIpAddresses'].map { |ip_address| ip_address['PrivateIpAddress'] }
        else
          []
        end
      end
    end
  end
end
