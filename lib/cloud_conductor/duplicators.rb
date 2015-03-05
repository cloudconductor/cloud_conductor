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
require 'cloud_conductor/duplicators/instance_duplicator'
require 'cloud_conductor/duplicators/subnet_duplicator'
require 'cloud_conductor/duplicators/network_interface_duplicator'

module CloudConductor
  module Duplicators
    extend DuplicatorUtils

    def self.increase_instance(template_json, parameters = {}, availability_zones = [])
      options = { AvailabilityZone: availability_zones }
      template = JSON.parse(template_json).with_indifferent_access

      resources = template['Resources']
      instances = resources.select(&type?('AWS::EC2::Instance'))
      instances.each do |instance_name, _instance_property|
        scale_size = parameters[:"#{instance_name}Size"] || 1
        (2..scale_size.to_i).each do |n|
          options.merge! CopyNum: n
          options.merge! Role: resources[instance_name]['Metadata']['Role']

          duplicator = InstanceDuplicator.new(resources, options)
          resources.merge! duplicator.copy(instance_name, {}, options)
        end
      end
      remove_copied_flag(template).to_json
    end

    def self.remove_copied_flag(template)
      template['Resources'].map do |_, resource|
        next unless resource['Metadata'] && resource['Metadata']['Copied']

        resource['Metadata'].delete 'Copied'
        resource.delete 'Metadata' if resource['Metadata'].empty?
      end
      template
    end
  end
end
