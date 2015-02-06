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
    describe 'DuplicatorUtils' do
      include DuplicatorUtils

      before do
        @instances = {
          'Instance1' => {
            'Type' => 'AWS::EC2::Instance',
            'Properties' => {
              'PrivateIpAddress' => '10.0.0.1',
              'NetworkInterfaces' => [{
                'PrivateIpAddress' => '10.0.0.2'
              }, {
                'PrivateIpAddresses' => [{
                  'PrivateIpAddress' => '10.0.0.3',
                  'Primary' => true
                }, {
                  'PrivateIpAddress' => '10.0.0.4',
                  'Primary' => false
                }]
              }]
            }
          }
        }

        @nics = {
          'NIC1' => {
            'Type' => 'AWS::EC2::NetworkInterface',
            'Properties' => {
              'GroupSet' => [
                { 'Ref' => 'SharedSecurityGroup' },
                { 'Ref' => 'WebSecurityGroup' }
              ],
              'PrivateIpAddress' => '10.0.0.5',
              'SubnetId' => { 'Ref' => 'Subnet1' }
            }
          },
          'NIC2' => {
            'Type' => 'AWS::EC2::NetworkInterface',
            'Properties' => {
              'GroupSet' => [
                { 'Ref' => 'SharedSecurityGroup' },
                { 'Ref' => 'WebSecurityGroup' }
              ],
              'PrivateIpAddresses' => [{
                'PrivateIpAddress' => '10.0.0.6',
                'Primary' => true
              }, {
                'PrivateIpAddress' => '10.0.0.7',
                'Primary' => false
              }],
              'SubnetId' => { 'Ref' => 'Subnet2' }
            }
          }
        }
      end

      describe '#type?' do
        it 'return lambda' do
          is_sample = type?('Sample')
          expect(is_sample.class).to eq(Proc)
          expect(is_sample.lambda?).to be_truthy
        end

        it 'return true when resource has Sample type' do
          is_sample = type?('Sample')
          resource = { Type: 'Sample' }
          expect(is_sample.call('Key', resource)).to be_truthy
        end

        it 'return false when resource hasn\'t Sample type' do
          is_sample = type?('Sample')
          resource = { Type: 'Test' }
          expect(is_sample.call('Key', resource)).to be_falsey
        end
      end

      describe '#get_allocatable_addresses' do
        it 'return allocatable IP address' do
          resources = @instances.merge @nics
          cidr = NetAddr::CIDR.create('10.0.0.0/24')
          addresses = get_allocatable_addresses(resources.with_indifferent_access, cidr)

          expect(addresses.include?('10.0.0.0')).to be_falsey
          expect(addresses.include?('10.0.0.1')).to be_falsey
          expect(addresses.include?('10.0.0.2')).to be_falsey
          expect(addresses.include?('10.0.0.3')).to be_falsey
          expect(addresses.include?('10.0.0.4')).to be_falsey
          expect(addresses.include?('10.0.0.5')).to be_falsey
          expect(addresses.include?('10.0.0.6')).to be_falsey
          expect(addresses.include?('10.0.0.7')).to be_falsey
          expect(addresses.include?('10.0.0.8')).to be_truthy
          expect(addresses.include?('10.0.0.255')).to be_falsey
        end
      end

      describe '#get_ip_address_for_instances' do
        it 'return ip address that is used in all of the Instance' do
          allow(self).to receive(:get_private_ip_address).and_call_original
          expect(get_ip_address_for_instances(@instances)).to eq(['10.0.0.1', '10.0.0.2', '10.0.0.3', '10.0.0.4'])
        end
      end

      describe '#get_ip_address_for_network_interface' do
        it 'return ip address that is used in all of the NIC' do
          expect(get_ip_address_for_network_interface(@nics)).to eq(['10.0.0.5', '10.0.0.6', '10.0.0.7'])
        end
      end

      describe '#get_private_ip_address' do
        it 'return private ip address for NIC if nic have PrivateIpAddress property' do
          nic = {
            'PrivateIpAddress' => '10.0.0.1'
          }

          expect(get_private_ip_address(nic)).to eq(['10.0.0.1'])
        end

        it 'return private ip addresses for NIC if nic have PrivateIpAddresses property' do
          nic = {
            'PrivateIpAddresses' => [{
              'PrivateIpAddress' => '10.0.0.2',
              'Primary' => true
            }, {
              'PrivateIpAddress' => '10.0.0.3',
              'Primary' => false
            }]
          }

          expect(get_private_ip_address(nic)).to eq(['10.0.0.2', '10.0.0.3'])
        end

        it 'return empty array if nic not have PrivateIpAddress and PrivateIpAddresses property' do
          nic = {
            'Dummy' => 'sample'
          }

          expect(get_private_ip_address(nic)).to eq([])
        end
      end
    end
  end
end
