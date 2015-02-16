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
    describe NetworkInterfaceDuplicator do
      describe '#change_for_properties' do
        before do
          @resources = {
            'Instance1' => {
              'Type' => 'AWS::EC2::Instance',
              'Properties' => {
                'PrivateIpAddress' => '10.0.1.1'
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
          nic_resource = {
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
            }
          }
          resources = @resources.merge nic_resource
          nic_duplicator = NetworkInterfaceDuplicator.new(resources.with_indifferent_access, @options)

          nic_duplicator.change_for_properties(nic_resource['NIC1'])
          expect(nic_resource['NIC1']['Properties']['PrivateIpAddress']).to eq('10.0.1.2')
        end

        it 'return resource that have updated PrivateIpAddresses' do
          nic_resource = {
            'NIC2' => {
              'Type' => 'AWS::EC2::NetworkInterface',
              'Properties' => {
                'GroupSet' => [
                  { 'Ref' => 'SharedSecurityGroup' },
                  { 'Ref' => 'WebSecurityGroup' }
                ],
                'PrivateIpAddresses' => [{
                  'PrivateIpAddress' => '10.0.1.1',
                  'Primary' => true
                }, {
                  'PrivateIpAddress' => '10.0.1.2',
                  'Primary' => false
                }],
                'SubnetId' => { 'Ref' => 'Subnet1' }
              }
            }
          }
          resources = @resources.merge nic_resource
          nic_duplicator = NetworkInterfaceDuplicator.new(resources.with_indifferent_access, @options)

          nic_duplicator.change_for_properties(nic_resource['NIC2'])
          expect(nic_resource['NIC2']['Properties']['PrivateIpAddresses'].first['PrivateIpAddress']).to eq('10.0.1.3')
          expect(nic_resource['NIC2']['Properties']['PrivateIpAddresses'].last['PrivateIpAddress']).to eq('10.0.1.4')
        end
      end
    end
  end
end
