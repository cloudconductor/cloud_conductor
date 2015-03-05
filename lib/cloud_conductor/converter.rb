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
require 'cloud_conductor/duplicators'

module CloudConductor
  class Converter
    def type?(type)
      ->(_, resource) { resource[:Type] == type }
    end

    def update_cluster_addresses(template_json)
      template = JSON.parse(template_json).with_indifferent_access
      instances = template['Resources'].select(&type?('AWS::EC2::Instance'))

      instances.each do |_, instance_property|
        instance_property[:Metadata] ||= {}
        instance_property[:Metadata][:ClusterAddresses] = cluster_addresses(instances)
      end

      template[:Outputs] ||= {}
      template[:Outputs][:ClusterAddresses] = {
        Value: cluster_addresses(instances),
        Description: 'Private IP Addresses to join cluster. This output is required.'
      }

      template.to_json
    end

    private

    def cluster_addresses(instances)
      return @cluster_addresses if @cluster_addresses

      leader_instances = instances.select do |_, instance_property|
        metadata = (instance_property[:Metadata] || {})
        metadata[:Frontend] == true || metadata[:Frontend] == 'true'
      end

      cluster_addresses = leader_instances.map do |_, instance_property|
        network_interface_name = instance_property[:Properties][:NetworkInterfaces].first[:NetworkInterfaceId][:Ref]
        { 'Fn::GetAtt' => [network_interface_name, 'PrimaryPrivateIpAddress'] }
      end

      @cluster_addresses = { 'Fn::Join' => [',', cluster_addresses] }
    end
  end
end
