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
require_relative 'base_duplicator'


module CloudConductor
  module Duplicators
    class SubnetDuplicator < BaseDuplicator
      include DuplicatorUtils

      def post(resource)
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

      def copy(source_name, copy_num, name_map = {}, options = {})
        subnets = @resources.select(&type?('AWS::EC2::Subnet')).keys
        return super if subnets.size < @options[:AvailabilityZone].size

        return if name_map.keys.include? source_name

        old_index = subnets.index(source_name)
        new_index = (old_index + @options[:CopyNum] - 1) % subnets.size
        name_map[source_name] = subnets[new_index]
      end
    end
  end
end
