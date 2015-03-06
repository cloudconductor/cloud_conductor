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
require 'cloud_conductor/adapters'
require 'cloud_conductor/converter'

module CloudConductor
  class Client
    attr_reader :type, :adapter

    def initialize(cloud)
      @cloud = cloud
      @type = cloud.type
      case cloud.type
      when 'aws'
        @adapter = CloudConductor::Adapters::AWSAdapter.new
      when 'openstack'
        @adapter = CloudConductor::Adapters::OpenStackAdapter.new
      else
        fail "Cannnot find #{cloud.type} adapter"
      end
    end

    def create_stack(name, pattern, parameters)
      template = ''
      pattern.clone_repository do |path|
        template = open(File.expand_path('template.json', path)).read
      end

      az_list = @adapter.get_availability_zones @cloud.attributes
      template = CloudConductor::Converter::Duplicators.increase_instance(template, parameters, az_list)
      template = CloudConductor::Converter.new.update_cluster_addresses(template) if pattern.type == 'platform'

      images = pattern.images.where(cloud: @cloud)

      images.each do |image|
        parameters["#{image.role.gsub(/\s*,\s*/, '')}ImageId"] = image.image
      end

      @adapter.create_stack name, template, parameters, @cloud.attributes
    end

    def update_stack(name, pattern, parameters)
      template = ''
      pattern.clone_repository do |path|
        template = open(File.expand_path('template.json', path)).read
      end

      az_list = @adapter.get_availability_zones @cloud.attributes
      template = CloudConductor::Converter::Duplicators.increase_instance(template, parameters, az_list)
      template = CloudConductor::Converter.new.update_cluster_addresses(template) if pattern.type == 'platform'

      images = pattern.images.where(cloud: @cloud)

      images.each do |image|
        parameters["#{image.role.gsub(/\s*,\s*/, '')}ImageId"] = image.image
      end

      @adapter.update_stack name, template, parameters, @cloud.attributes
    end

    def get_stack_status(name)
      @adapter.get_stack_status name, @cloud.attributes
    end

    def get_outputs(name)
      @adapter.get_outputs name, @cloud.attributes
    end

    def destroy_stack(name)
      @adapter.destroy_stack name, @cloud.attributes
    end

    def post_process
      @adapter.post_process
    end
  end
end
