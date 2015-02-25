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
    describe InstanceDuplicator do
      describe '#change_properties' do
        before do
          @resources = {
            'NIC1' => {
              'Type' => 'AWS::EC2::NetworkInterface',
              'Properties' => {
                'GroupSet' => [
                  { 'Ref' => 'SharedSecurityGroup' },
                  { 'Ref' => 'WebSecurityGroup' }
                ],
                'PrivateIpAddress' => '10.0.1.1',
                'SubnetId' => { 'Ref' => 'Subnet1' }
              }
            },
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
            AvailabilityZones: ['ap-southeast-2a', 'ap-southeast-2b'],
            CopyNum: 2
          }
        end

        it 'return resource that have updated PrivateIpAddress' do
          instance = {
            'Instance1' => {
              'Type' => 'AWS::EC2::Instance',
              'Properties' => {
                'NetworkInterfaces' => [{
                  'SubnetId' => { 'Ref' => 'Subnet1' },
                  'PrivateIpAddress' => '10.0.1.1'
                }]
              }
            }
          }
          resources = @resources.merge instance
          instance_duplicator = InstanceDuplicator.new(resources.with_indifferent_access, @options)

          instance_duplicator.change_properties(instance['Instance1'])
          expect(instance['Instance1']['Properties']['NetworkInterfaces'].first['PrivateIpAddress']).to eq('10.0.1.2')
        end

        it 'return resource that have updated PrivateIpAddresses' do
          instance = {
            'Instance1' => {
              'Type' => 'AWS::EC2::Instance',
              'Properties' => {
                'NetworkInterfaces' => [{
                  'SubnetId' => { 'Ref' => 'Subnet1' },
                  'PrivateIpAddresses' => [{
                    'PrivateIpAddress' => '10.0.1.1',
                    'Primary' => true
                  }, {
                    'PrivateIpAddress' => '10.0.1.2',
                    'Primary' => false
                  }]
                }]
              }
            }
          }
          resources = @resources.merge instance
          instance_duplicator = InstanceDuplicator.new(resources.with_indifferent_access, @options)

          instance_duplicator.change_properties(instance['Instance1'])
          addresses = instance['Instance1']['Properties']['NetworkInterfaces'].first['PrivateIpAddresses']
          expect(addresses.first['PrivateIpAddress']).to eq('10.0.1.3')
          expect(addresses.last['PrivateIpAddress']).to eq('10.0.1.4')
        end

        it 'do not do anything if the Network Interface is not embedded in the Instance' do
          instance = {
            'Instance1' => {
              'Type' => 'AWS::EC2::Instance',
              'Properties' => {
                'NetworkInterfaces' => [{
                  'DeviceIndex' => '0',
                  'NetworkInterfaceId' => { 'Ref' => 'WebNetworkInterface1' }
                }]
              }
            }
          }
          resources = @resources.merge instance
          instance_duplicator = InstanceDuplicator.new(resources.with_indifferent_access, @options)

          posted_resource = instance_duplicator.change_properties(instance['Instance1'])
          expect(posted_resource).to eq(instance['Instance1'])
        end
      end
    end
  end
end
