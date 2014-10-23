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

module CloudConductor
  class Client
    attr_reader :type, :adapter

    def initialize(cloud)
      @cloud = cloud
      @type = cloud.type

      # load adapters
      if Adapters.constants.empty?
        Dir.glob(File.expand_path('./adapters/*.rb', File.dirname(__FILE__))) do |file|
          require file
        end
      end

      adapter_name = Adapters.constants.find do |klass_name|
        klass = Adapters.const_get(klass_name)
        klass.const_get(:TYPE) == @type if klass.constants.include? :TYPE
      end

      @adapter = Adapters.const_get(adapter_name).new
    end

    def create_stack(name, pattern, parameters)
      template = ''
      pattern.clone_repository do |path|
        template = open(File.expand_path('template.json', path)).read
      end

      operating_system = OperatingSystem.where(name: 'centos')
      images = pattern.images.where(cloud: @cloud, operating_system: operating_system)
      fail 'Appropriate image does not exist' if images.empty?

      images.each do |image|
        parameters["#{image.role.gsub(/\s*,\s*/, '')}ImageId"] = image.image
      end

      @adapter.create_stack name, template, parameters, @cloud.attributes
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
  end
end
