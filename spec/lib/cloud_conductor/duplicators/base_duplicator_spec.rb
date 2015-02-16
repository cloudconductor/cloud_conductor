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
    describe BaseDuplicator do
      before do
        @resources = {}
        @options = {}
        @base_duplicator = BaseDuplicator.new(@resources, @options)
      end

      describe '#change_for_properties' do
        it 'return the argument as it is' do
          resource = { 'Type' => 'AWS::EC2::Instance' }
          expect(@base_duplicator.send(:change_for_properties, resource)).to eq('Type' => 'AWS::EC2::Instance')
        end
      end

      describe '#copy' do
        it 'duplicate resource' do
          resources = {
            'FrontendEIP' => {
              'Type' => 'AWS::EC2::EIP',
              'Properties' => {
                'Domain' => 'vpc'
              }
            },
            'WebSecurityGroup' => {
              'Type' => 'AWS::EC2::SecurityGroup',
              'Properties' => {
                'VpcId' => { 'Ref' => 'VPC' },
                'SecurityGroupIngress' => [
                  { 'IpProtocol' => 'tcp', 'FromPort' => '80', 'ToPort' => '80', 'CidrIp' => '0.0.0.0/0' }
                ]
              }
            }
          }

          result_resource = {
            'FrontendEIP' => {
              'Type' => 'AWS::EC2::EIP',
              'Properties' => {
                'Domain' => 'vpc'
              }
            },
            'WebSecurityGroup' => {
              'Type' => 'AWS::EC2::SecurityGroup',
              'Properties' => {
                'VpcId' => { 'Ref' => 'VPC' },
                'SecurityGroupIngress' => [
                  { 'IpProtocol' => 'tcp', 'FromPort' => '80', 'ToPort' => '80', 'CidrIp' => '0.0.0.0/0' }
                ]
              }
            },
            'FrontendEIP2' => {
              'Type' => 'AWS::EC2::EIP',
              'Properties' => {
                'Domain' => 'vpc'
              },
              'Metadata' => {
                'Copied' => 'true'
              }
            }
          }

          options = {
            AvailabilityZone: ['ap-southeast-2a', 'ap-southeast-2b'],
            CopyNum: 2
          }

          @base_duplicator = BaseDuplicator.new(resources, options)
          @base_duplicator.copy('FrontendEIP', 2, {}, options)

          expect(resources).to eq(result_resource)
        end
      end

      describe '#copy?' do
        it 'return true when resource exist in the COPYABLE_RESOURCES ' do
          resource = { 'Type' => 'AWS::EC2::Instance' }
          expect(@base_duplicator.send(:copy?, resource)).to be_truthy
        end

        it 'return true when resource not exist in the COPYABLE_RESOURCES ' do
          resource = { 'Type' => 'AWS::EC2::VPC' }
          expect(@base_duplicator.send(:copy?, resource)).to be_falsey
        end
      end

      describe '#create_duplicator' do
        it 'return instance of InstanceDuplicator if type is AWS::EC2::Instance' do
          duplicator = @base_duplicator.send(:create_duplicator, 'AWS::EC2::Instance')
          expect(duplicator.class).to eq(InstanceDuplicator)
        end

        it 'return instance of SubnetDuplicator if type is AWS::EC2::Subnet' do
          duplicator = @base_duplicator.send(:create_duplicator, 'AWS::EC2::Subnet')
          expect(duplicator.class).to eq(SubnetDuplicator)
        end

        it 'return instance of NetworkInterfaceDuplicator if type is AWS::EC2::NetworkInterface' do
          duplicator = @base_duplicator.send(:create_duplicator, 'AWS::EC2::NetworkInterface')
          expect(duplicator.class).to eq(NetworkInterfaceDuplicator)
        end

        it 'return instance of BaseDuplicator if class is nonexistent' do
          duplicator = @base_duplicator.send(:create_duplicator, 'Dummy')
          expect(duplicator.class).to eq(BaseDuplicator)
        end
      end

      describe '#contain_ref' do
        it 'return true when template has Ref entry with specified resource' do
          resource = { Ref: 'Route' }
          expect(@base_duplicator.send(:contain_ref, 'Route', resource)).to be_truthy
        end

        it 'return true when deep hash has Ref entry' do
          resource = { Dummy: { Ref: 'Route' } }
          expect(@base_duplicator.send(:contain_ref, 'Route', resource)).to be_truthy
        end

        it 'return true when deep array has Ref entry' do
          resource = { Dummy: [{ Ref: 'Route' }] }
          expect(@base_duplicator.send(:contain_ref, 'Route', resource)).to be_truthy
        end

        it 'return false when template hasn\'t Ref entry' do
          resource = { Dummy: [{ Hoge: 'Route' }] }
          expect(@base_duplicator.send(:contain_ref, 'Route', resource)).to be_falsey
        end

        it 'return false when template hasn\'t Ref entry with specified resource' do
          resource = { Dummy: [{ Ref: 'Hoge' }] }
          expect(@base_duplicator.send(:contain_ref, 'Route', resource)).to be_falsey
        end
      end

      describe '#contain_get_att' do
        it 'return true when template has GetAtt entry with specified resource' do
          resource = { :'Fn::GetAtt' => %w(Route Dummy) }
          expect(@base_duplicator.send(:contain_get_att, 'Route', resource)).to be_truthy
        end

        it 'return true when deep hash has GetAtt entry' do
          resource = { Dummy: { :'Fn::GetAtt' => %w(Route Dummy) } }
          expect(@base_duplicator.send(:contain_get_att, 'Route', resource)).to be_truthy
        end

        it 'return true when deep array has GetAtt entry' do
          resource = { Dummy: [{ :'Fn::GetAtt' => %w(Route Dummy) }] }
          expect(@base_duplicator.send(:contain_get_att, 'Route', resource)).to be_truthy
        end

        it 'return false when template hasn\'t Ref entry' do
          resource = { Dummy: [{ Dummy: %w(Route Dummy) }] }
          expect(@base_duplicator.send(:contain_get_att, 'Route', resource)).to be_falsey
        end

        it 'return false when template hasn\'t Ref entry with specified resource' do
          resource = { Dummy: [{ :'Fn::GetAtt' => %w(Hoge Dummy) }] }
          expect(@base_duplicator.send(:contain_get_att, 'Route', resource)).to be_falsey
        end
      end

      describe '#contain_depends_on' do
        it 'return true when template has DependsOn entry with specified resource' do
          resource = { DependsOn: 'Route' }
          expect(@base_duplicator.send(:contain_depends_on, 'Route', resource)).to be_truthy
        end

        it 'return true when template has DependsOn entry with specified resource' do
          resource = { DependsOn: %w(Route dummy) }
          expect(@base_duplicator.send(:contain_depends_on, 'Route', resource)).to be_truthy
        end

        it 'return false when template hasn\'t DependsOn entry' do
          resource = { Dummy: 'Route' }
          expect(@base_duplicator.send(:contain_depends_on, 'Route', resource)).to be_falsey
        end

        it 'return false when template hasn\'t DependsOn entry with specified resource' do
          resource = { DependsOn: 'Hoge' }
          expect(@base_duplicator.send(:contain_depends_on, 'Route', resource)).to be_falsey
        end
      end

      describe '#contain_association?' do
        before do
          allow(@base_duplicator).to receive(:contain_ref).and_return(false)
          allow(@base_duplicator).to receive(:contain_get_att).and_return(false)
          allow(@base_duplicator).to receive(:contain_depends_on).and_return(false)

          @contain_sample = @base_duplicator.send(:contain_association?, 'Route')
        end
      end

      describe '#collect_ref' do
        it 'return Ref value when template has Ref entry with specified resource' do
          resource = { 'Ref' => 'Route' }
          expect(@base_duplicator.send(:collect_ref, resource)).to eq(['Route'])
        end

        it 'return Ref value when deep hash has Ref entry' do
          resource = { Dummy: { 'Ref' => 'Route' } }
          expect(@base_duplicator.send(:collect_ref, resource)).to eq(['Route'])
        end

        it 'return Ref value when deep array has Ref entry' do
          resource = { Dummy: [{ 'Ref' => 'Route' }] }
          expect(@base_duplicator.send(:collect_ref, resource)).to eq(['Route'])
        end

        it 'not return Ref value when template hasn\'t Ref entry' do
          resource = { Dummy: [{ Hoge: 'Route' }] }
          expect(@base_duplicator.send(:collect_ref, resource)).to eq([])
        end
      end

      describe '#collect_get_att' do
        it 'return GetAtt value when template has GetAtt entry with specified resource' do
          obj = { 'Fn::GetAtt' => %w(Route Dummy) }
          expect(@base_duplicator.send(:collect_get_att, obj)).to eq(['Route'])
        end

        it 'return GetAtt value when deep hash has GetAtt entry' do
          obj = { Dummy: { 'Fn::GetAtt' => %w(Route Dummy) } }
          expect(@base_duplicator.send(:collect_get_att, obj)).to eq(['Route'])
        end

        it 'return GetAtt value when deep array has GetAtt entry' do
          obj = { Dummy: [{ 'Fn::GetAtt' => %w(Route Dummy) }] }
          expect(@base_duplicator.send(:collect_get_att, obj)).to eq(['Route'])
        end

        it 'not return GetAtt value when template hasn\'t Ref entry' do
          obj = { Dummy: [{ Dummy: %w(Route Dummy) }] }
          expect(@base_duplicator.send(:collect_get_att, obj)).to eq([])
        end
      end

      describe '#collect_depends_on' do
        it 'return DependsOn value when template has DependsOn entry with specified resource' do
          obj = { 'DependsOn' => 'Route' }
          expect(@base_duplicator.send(:collect_depends_on, obj)).to eq(['Route'])
        end

        it 'return DependsOn value when template has DependsOn entry with specified resource' do
          obj = { 'DependsOn' => %w(Route Dummy) }
          expect(@base_duplicator.send(:collect_depends_on, obj)).to eq(%w(Route Dummy))
        end

        it 'not return DependsOn value when template hasn\'t DependsOn entry' do
          obj = { Dummy: 'Route' }
          expect(@base_duplicator.send(:collect_depends_on, obj)).to eq([])
        end
      end

      describe 'collect_association' do
        before do
          resources = {
            'Instance1' => {
              'Type' => 'AWS::EC2::Instance',
              'Properties' => {
                'UserData' => {
                  'Fn::GetAtt' => %w(VPC1 PrimaryPrivateIpAddress)
                }
              }
            },
            'Subnet1' => {
              'Type' => 'AWS::EC2::Subnet',
              'Properties' => {
                'VpcId' => { 'Ref' => 'VPC1' }
              }
            },
            'FrontendEIP1' => {
              'Type' => 'AWS::EC2::EIP',
              'Properties' => {
                'Domain' => 'vpc'
              }
            },
            'WebWaitHandle1' => {
              'Type' => 'AWS::CloudFormation::WaitConditionHandle'
            },
            'WaitCondition1' => {
              'Type' => 'AWS::CloudFormation::WaitCondition',
              'DependsOn' => 'VPC1',
              'Properties' => {
                'Timeout' => '600'
              }
            }
          }
          @resource = {
            'VPC' => {
              'Type' => 'AWS::EC2::VPC',
              'Properties' => {
                'CidrBlock' => '10.0.0.0/24'
              }
            }
          }

          @base_duplicator = BaseDuplicator.new(resources, @options)
          allow(@base_duplicator).to receive(:collect_ref).and_return('Instance1')
          allow(@base_duplicator).to receive(:collect_get_att).and_return('Subnet1')
          allow(@base_duplicator).to receive(:collect_depends_on).and_return('WaitCondition1')
        end

        it 'call collect_ref, collect_get_att, collect_depends_on' do
          expect(@base_duplicator).to receive(:collect_ref).with(@resource)
          expect(@base_duplicator).to receive(:collect_get_att).with(@resource)
          expect(@base_duplicator).to receive(:collect_depends_on).with(@resource)

          @base_duplicator.send(:collect_association, @resource)
        end

        it 'return resource that match from the resource to returned value' do
          collect_result =  @base_duplicator.send(:collect_association, @resource)

          expect(collect_result.include?('Instance1')).to be_truthy
          expect(collect_result.include?('Subnet1')).to be_truthy
          expect(collect_result.include?('WaitCondition1')).to be_truthy
          expect(collect_result.include?('FrontendEIP1')).to be_falsey
          expect(collect_result.include?('WebWaitHandle1')).to be_falsey
        end
      end

      describe '#change_for_ref' do
        it 'change Ref property in single hierarchy' do
          resource = {
            'Ref' => 'DummyProperty'
          }
          old_name = 'DummyProperty'
          new_name = 'TestProperty'

          @base_duplicator.send(:change_for_ref, old_name, new_name, resource)
          expect(resource['Ref']).to eq('TestProperty')
        end

        it 'change Ref property in single hierarchy' do
          resource = {
            'EIPAssociation1' => {
              'Type' => 'AWS::EC2::EIPAssociation',
              'Properties' => {
                'NetworkInterfaceId' => { 'Ref' => 'DummyProperty' }
              }
            }
          }
          old_name = 'DummyProperty'
          new_name = 'TestProperty'

          @base_duplicator.send(:change_for_ref, old_name, new_name, resource)
          expect(resource['EIPAssociation1']['Properties']['NetworkInterfaceId']['Ref']).to eq('TestProperty')
        end
      end

      describe '#change_for_get_att' do
        it 'change Fn::GetAtt property in single hierarchy' do
          resource = {
            'Fn::GetAtt' => %w(DummyProperty AllocationId)
          }
          old_name = 'DummyProperty'
          new_name = 'TestProperty'

          @base_duplicator.send(:change_for_get_att, old_name, new_name, resource)
          expect(resource['Fn::GetAtt']).to eq(%w(TestProperty AllocationId))
        end

        it 'change Fn::GetAtt property in multi hierarchy' do
          resource = {
            'EIPAssociation1' => {
              'Type' => 'AWS::EC2::EIPAssociation',
              'Properties' => {
                'AllocationId' => { 'Fn::GetAtt' => %w(DummyProperty AllocationId) },
                'NetworkInterfaceId' => { 'Ref' => 'WebNetworkInterface1' }
              }
            }
          }
          old_name = 'DummyProperty'
          new_name = 'TestProperty'

          @base_duplicator.send(:change_for_get_att, old_name, new_name, resource)
          expect(resource['EIPAssociation1']['Properties']['AllocationId']['Fn::GetAtt']).to eq(%w(TestProperty AllocationId))
        end
      end

      describe '#change_for_depends_on' do
        it 'change DependsOn property if DependsOn property is string' do
          resource = { 'DependsOn' => 'dummy_name' }
          old_name = 'dummy_name'
          new_name = 'test_name'

          @base_duplicator.send(:change_for_depends_on, old_name, new_name, resource)
          expect(resource['DependsOn']).to eq('test_name')
        end

        it 'change DependsOn property if DependsOn property is array' do
          resource = { 'DependsOn' => %w(dummy_name dummy_depends) }
          old_name = 'dummy_name'
          new_name = 'test_name'

          @base_duplicator.send(:change_for_depends_on, old_name, new_name, resource)
          expect(resource['DependsOn']).to eq(%w(test_name dummy_depends))

          resource = { 'DependsOn' => %w(dummy_depends dummy_name) }

          @base_duplicator.send(:change_for_depends_on, old_name, new_name, resource)
          expect(resource['DependsOn']).to eq(%w(dummy_depends test_name))
        end
      end

      describe 'change_for_association' do
        before do
          allow(@base_duplicator).to receive(:change_for_ref)
          allow(@base_duplicator).to receive(:change_for_get_att)
          allow(@base_duplicator).to receive(:change_for_depends_on)

          @resource = {}
          @old_and_new_name_list = { old_name1: 'new_name1' }
        end

        it 'call change_for_ref, change_for_get_att, change_for_depends_on' do
          expect(@base_duplicator).to receive(:change_for_ref).with(:old_name1, 'new_name1', @resource)
          expect(@base_duplicator).to receive(:change_for_get_att).with(:old_name1, 'new_name1', @resource)
          expect(@base_duplicator).to receive(:change_for_depends_on).with(:old_name1, 'new_name1', @resource)

          @base_duplicator.send(:change_for_association, @old_and_new_name_list, @resource)
        end

        it 'call change_for_ref, change_for_get_att, change_for_depends_on for the size of old_and_new_name_list' do
          expect(@base_duplicator).to receive(:change_for_ref).twice
          expect(@base_duplicator).to receive(:change_for_get_att).twice
          expect(@base_duplicator).to receive(:change_for_depends_on).twice

          old_and_new_name_list = { old_name1: 'new_name1', old_name2: 'new_name2' }
          @base_duplicator.send(:change_for_association, old_and_new_name_list, @resource)
        end
      end
    end
  end
end
