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
require 'netaddr'
require 'cloud_conductor/duplicators/base_duplicator'

module CloudConductor
  module Duplicators
    class SubnetDuplicator < BaseDuplicator
      include DuplicatorUtils

      def change_for_properties(copied_resource)
        used_availability_zones = @resources.select(&type?('AWS::EC2::Subnet')).map do |_, value|
          value['Properties']['AvailabilityZone']
        end
        new_availavility_zone = (@options[:AvailabilityZone] - used_availability_zones).first
        copied_resource['Properties']['AvailabilityZone'] = new_availavility_zone

        cidr = NetAddr::CIDR.create(copied_resource['Properties']['CidrBlock'])
        new_cidr = (@options[:CopyNum] - 1).times.inject(cidr) do |s, _|
          s.succ
        end
        copied_resource['Properties']['CidrBlock'] = new_cidr.to_s

        copied_resource
      end

      def copy(source_name, old_and_new_name_list = {}, options = {})
        subnet_names = @resources.select(&type?('AWS::EC2::Subnet')).keys
        return super if subnet_names.size < @options[:AvailabilityZone].size

        return { source_name => @resources[source_name] } if old_and_new_name_list.keys.include? source_name

        old_index = subnet_names.index(source_name)
        new_index = (old_index + @options[:CopyNum] - 1) % subnet_names.size
        old_and_new_name_list[source_name] = subnet_names[new_index]
        { subnet_names[new_index] => @resources[subnet_names[new_index]] }
      end
    end
  end
end
