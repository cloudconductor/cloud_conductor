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
    class SubnetDuplicator < BaseDuplicator
      include DuplicatorUtils

      def replace_properties(resource)
        used_availability_zones = @resources.select(&type?('AWS::EC2::Subnet')).map do |_, value|
          value['Properties']['AvailabilityZone']
        end
        new_availavility_zone = (@options[:AvailabilityZone] - used_availability_zones).first
        resource['Properties']['AvailabilityZone'] = new_availavility_zone

        cidr = NetAddr::CIDR.create(resource['Properties']['CidrBlock'])
        new_cidr = (@options[:CopyNum] - 1).times.inject(cidr) do |s, _|
          s.succ
        end
        resource['Properties']['CidrBlock'] = new_cidr.to_s

        resource
      end

      def copy(source_name, copied_resource_mapping_table = {}, options = {})
        subnet_names = @resources.select(&type?('AWS::EC2::Subnet')).keys
        return super if subnet_names.size < @options[:AvailabilityZone].size

        return { source_name => @resources[source_name] } if copied_resource_mapping_table.keys.include? source_name

        old_index = subnet_names.index(source_name)
        new_index = (old_index + @options[:CopyNum] - 1) % subnet_names.size
        copied_resource_mapping_table[source_name] = subnet_names[new_index]
        { subnet_names[new_index] => @resources[subnet_names[new_index]] }
      end
    end
  end
end
