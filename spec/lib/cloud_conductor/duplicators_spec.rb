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
  module Duplicators
    describe '#copy_template' do
      def load_json(file_name)
        dir_path = File.expand_path('../../features/duplicators', File.dirname(__FILE__))
        file_path = File.expand_path("#{file_name}.json", dir_path)

        File.open(file_path).read
      end

      it 'return duplicated template' do
        single_json = JSON.parse(load_json('single'))
        multi_json = JSON.parse(load_json('multi'))
        desired_size_json = { 'WebServer' => 2 }
        availability_zones = ['ap-southeast-2a', 'ap-southeast-2b']

        result = CloudConductor::Duplicators.copy_template(single_json.with_indifferent_access, desired_size_json, availability_zones)

        expect(result['Resources']).to eq(multi_json['Resources'])
      end
    end
  end
end
