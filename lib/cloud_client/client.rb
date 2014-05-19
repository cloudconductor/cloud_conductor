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
require 'cloud_client/adapters'

module CloudClient
  class Client
    attr_reader :type, :adapter

    def initialize(type)
      @type = type

      # load adapters
      if Adapters.constants.empty?
        Dir.glob(File.expand_path('./adapters/*.rb', File.dirname(__FILE__))) do |file|
          require file
        end
      end

      adapter_name = Adapters.constants.find do |klass_name|
        klass = Adapters.const_get(klass_name)
        klass.const_get(:TYPE) == type if klass.constants.include? :TYPE
      end

      @adapter = Adapters.const_get(adapter_name).new
    end

    def create_stack(template, parameters, options)
      @adapter.create_stack template, parameters, options
    end
  end
end
