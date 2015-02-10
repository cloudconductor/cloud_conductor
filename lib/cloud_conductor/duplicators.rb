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
require_relative 'duplicators/instance_duplicator'
require_relative 'duplicators/subnet_duplicator'
require_relative 'duplicators/network_interface_duplicator'

module CloudConductor
  module Duplicators
    def self.copy_template(template, desired_size_json = {}, availability_zones = [])
      options = { AvailabilityZone: availability_zones }

      desired_size_json.each do |target_name, size|
        next unless template['Resources'][target_name]
        (2..size).each do |n|
          options.merge! CopyNum: n

          duplicator = InstanceDuplicator.new(template['Resources'], options)
          duplicator.copy(target_name, n, {}, options)
        end
      end
      template
    end
  end
end
