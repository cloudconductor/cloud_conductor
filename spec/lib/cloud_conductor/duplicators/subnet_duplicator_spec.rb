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
    describe SubnetDuplicator do
      before do
        @resource = {
          'Subnet1' => {
            'Type' => 'AWS::EC2::Subnet',
            'Properties' => {
              'AvailabilityZone' => 'ap-southeast-2a',
              'CidrBlock' => '10.0.1.0/24',
              'VpcId' => { 'Ref' => 'VPC' }
            }
          }
        }
        @options = {
          AvailabilityZone: ['ap-southeast-2a', 'ap-southeast-2b'],
          CopyNum: 2
        }
        @subnet_duplicator = SubnetDuplicator.new(@resource.with_indifferent_access, @options)
      end

      describe '#change_for_properties' do
        it 'return template to updated for AvailabilityZone property and CidrBlock property' do
          resource = @resource.deep_dup

          expect(resource['Subnet1']['Properties']['AvailabilityZone']).to eq('ap-southeast-2a')
          expect(resource['Subnet1']['Properties']['CidrBlock']).to eq('10.0.1.0/24')

          @subnet_duplicator.change_for_properties(resource.values.first)

          expect(resource['Subnet1']['Properties']['AvailabilityZone']).to eq('ap-southeast-2b')
          expect(resource['Subnet1']['Properties']['CidrBlock']).to eq('10.0.2.0/24')
        end
      end

      describe '#copy' do
        before do
          @name_map = {
            'old_dummy_name' => 'new_old_name'
          }
        end

        it 'call BaseDuplicator#copy method if Subnet can copy' do
          allow_any_instance_of(BaseDuplicator).to receive(:copy)

          expect(@subnet_duplicator.copy('dummy_name', 2, @name_map, {}))
        end

        it 'do not do anything if Subnet have already been copied' do
          expect(@subnet_duplicator.copy('old_dummy_name', 2, @name_map, {})).to eq(nil)
        end

        it 'update name_map' do
          resources = {
            'Subnet1' => {
              'Type' => 'AWS::EC2::Subnet',
              'Properties' => {
                'AvailabilityZone' => 'ap-southeast-2a',
                'CidrBlock' => '10.0.1.0/24',
                'VpcId' => { 'Ref' => 'VPC' }
              }
            },
            'Subnet2' => {
              'Type' => 'AWS::EC2::Subnet',
              'Properties' => {
                'AvailabilityZone' => 'ap-southeast-2b',
                'CidrBlock' => '10.0.2.0/24',
                'VpcId' => { 'Ref' => 'VPC' }
              }
            }
          }

          subnet_duplicator = SubnetDuplicator.new(resources.with_indifferent_access, @options)

          name_map = {}

          subnet_duplicator.copy('Subnet1', 2, name_map, {})
          expect(name_map['Subnet1']).to eq('Subnet2')
        end
      end
    end
  end
end
