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
require 'cloud_conductor/converter/duplicators'

module CloudConductor
  class Converter
    module Duplicators
      describe '#increase_instance' do
        def load_json(file_name)
          dir_path = File.expand_path('../../../features/duplicators', File.dirname(__FILE__))
          file_path = File.expand_path("#{file_name}.json", dir_path)

          File.open(file_path).read
        end

        it 'return duplicated template' do
          single_json = load_json('single')
          multi_json = load_json('multi')
          parameters = { WebServerSize: '2' }
          availability_zones = ['ap-southeast-2a', 'ap-southeast-2b']

          result = CloudConductor::Converter::Duplicators.increase_instance(single_json, parameters, availability_zones)

          expect(result['Resources']).to eq(multi_json['Resources'])
        end
      end

      describe '#remove_copied_flag' do
        it 'remove copied in metadata resource' do
          template = {
            'Resources' => {
              'Instance' => {
                'Metadata' => {
                  'Role' => 'spec',
                  'Copied' => 'true'
                }
              }
            }
          }
          expected_template = {
            'Resources' => {
              'Instance' => {
                'Metadata' => {
                  'Role' => 'spec'
                }
              }
            }
          }

          result_template = CloudConductor::Converter::Duplicators.remove_copied_flag template
          expect(result_template).to eq(expected_template)
        end

        it 'remove metadata resource when metadata resource is empty' do
          template = {
            'Resources' => {
              'Instance' => {
                'Metadata' => {
                  'Copied' => 'true'
                },
                'DummyKey' => 'DummyValue'
              }
            }
          }
          expected_template = {
            'Resources' => {
              'Instance' => {
                'DummyKey' => 'DummyValue'
              }
            }
          }

          result_template = CloudConductor::Converter::Duplicators.remove_copied_flag template
          expect(result_template).to eq(expected_template)
        end
      end
    end
  end
end
