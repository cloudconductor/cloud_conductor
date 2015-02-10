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

      describe '#post' do
        it 'return the argument as it is' do
          resource = { 'Type' => 'AWS::EC2::Instance' }
          expect(@base_duplicator.send(:post, resource)).to eq('Type' => 'AWS::EC2::Instance')
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
          obj = { Ref: 'Route' }
          expect(@base_duplicator.send(:contain_ref, obj, 'Route')).to be_truthy
        end

        it 'return true when deep hash has Ref entry' do
          obj = { Dummy: { Ref: 'Route' } }
          expect(@base_duplicator.send(:contain_ref, obj, 'Route')).to be_truthy
        end

        it 'return true when deep array has Ref entry' do
          obj = { Dummy: [{ Ref: 'Route' }] }
          expect(@base_duplicator.send(:contain_ref, obj, 'Route')).to be_truthy
        end

        it 'return false when template hasn\'t Ref entry' do
          obj = { Dummy: [{ Hoge: 'Route' }] }
          expect(@base_duplicator.send(:contain_ref, obj, 'Route')).to be_falsey
        end

        it 'return false when template hasn\'t Ref entry with specified resource' do
          obj = { Dummy: [{ Ref: 'Hoge' }] }
          expect(@base_duplicator.send(:contain_ref, obj, 'Route')).to be_falsey
        end
      end

      describe '#contain_att' do
        it 'return true when template has GetAtt entry with specified resource' do
          obj = { :'Fn::GetAtt' => %w(Route Dummy) }
          expect(@base_duplicator.send(:contain_att, obj, 'Route')).to be_truthy
        end

        it 'return true when deep hash has GetAtt entry' do
          obj = { Dummy: { :'Fn::GetAtt' => %w(Route Dummy) } }
          expect(@base_duplicator.send(:contain_att, obj, 'Route')).to be_truthy
        end

        it 'return true when deep array has GetAtt entry' do
          obj = { Dummy: [{ :'Fn::GetAtt' => %w(Route Dummy) }] }
          expect(@base_duplicator.send(:contain_att, obj, 'Route')).to be_truthy
        end

        it 'return false when template hasn\'t Ref entry' do
          obj = { Dummy: [{ Dummy: %w(Route Dummy) }] }
          expect(@base_duplicator.send(:contain_att, obj, 'Route')).to be_falsey
        end

        it 'return false when template hasn\'t Ref entry with specified resource' do
          obj = { Dummy: [{ :'Fn::GetAtt' => %w(Hoge Dummy) }] }
          expect(@base_duplicator.send(:contain_att, obj, 'Route')).to be_falsey
        end
      end

      describe '#contain_depends' do
        it 'return true when template has DependsOn entry with specified resource' do
          obj = { DependsOn: 'Route' }
          expect(@base_duplicator.send(:contain_depends, obj, 'Route')).to be_truthy
        end

        it 'return true when template has DependsOn entry with specified resource' do
          obj = { DependsOn: %w(Route dummy) }
          expect(@base_duplicator.send(:contain_depends, obj, 'Route')).to be_truthy
        end

        it 'return false when template hasn\'t DependsOn entry' do
          obj = { Dummy: 'Route' }
          expect(@base_duplicator.send(:contain_depends, obj, 'Route')).to be_falsey
        end

        it 'return false when template hasn\'t DependsOn entry with specified resource' do
          obj = { DependsOn: 'Hoge' }
          expect(@base_duplicator.send(:contain_depends, obj, 'Route')).to be_falsey
        end
      end

      describe '#contain?' do
        before do
          allow(@base_duplicator).to receive(:contain_ref).and_return(false)
          allow(@base_duplicator).to receive(:contain_att).and_return(false)
          allow(@base_duplicator).to receive(:contain_depends).and_return(false)

          @contain_sample = @base_duplicator.send(:contain?, 'Route')
        end
      end

      describe '#collect_ref' do
        it 'return Ref value when template has Ref entry with specified resource' do
          obj = { 'Ref' => 'Route' }
          expect(@base_duplicator.send(:collect_ref, obj)).to eq(['Route'])
        end

        it 'return Ref value when deep hash has Ref entry' do
          obj = { Dummy: { 'Ref' => 'Route' } }
          expect(@base_duplicator.send(:collect_ref, obj)).to eq(['Route'])
        end

        it 'return Ref value when deep array has Ref entry' do
          obj = { Dummy: [{ 'Ref' => 'Route' }] }
          expect(@base_duplicator.send(:collect_ref, obj)).to eq(['Route'])
        end

        it 'not return Ref value when template hasn\'t Ref entry' do
          obj = { Dummy: [{ Hoge: 'Route' }] }
          expect(@base_duplicator.send(:collect_ref, obj)).to eq([])
        end
      end

      describe '#collect_att' do
        it 'return GetAtt value when template has GetAtt entry with specified resource' do
          obj = { 'Fn::GetAtt' => %w(Route Dummy) }
          expect(@base_duplicator.send(:collect_att, obj)).to eq(['Route'])
        end

        it 'return GetAtt value when deep hash has GetAtt entry' do
          obj = { Dummy: { 'Fn::GetAtt' => %w(Route Dummy) } }
          expect(@base_duplicator.send(:collect_att, obj)).to eq(['Route'])
        end

        it 'return GetAtt value when deep array has GetAtt entry' do
          obj = { Dummy: [{ 'Fn::GetAtt' => %w(Route Dummy) }] }
          expect(@base_duplicator.send(:collect_att, obj)).to eq(['Route'])
        end

        it 'not return GetAtt value when template hasn\'t Ref entry' do
          obj = { Dummy: [{ Dummy: %w(Route Dummy) }] }
          expect(@base_duplicator.send(:collect_att, obj)).to eq([])
        end
      end

      describe '#collect_depends' do
        it 'return DependsOn value when template has DependsOn entry with specified resource' do
          obj = { 'DependsOn' => 'Route' }
          expect(@base_duplicator.send(:collect_depends, obj)).to eq(['Route'])
        end

        it 'return DependsOn value when template has DependsOn entry with specified resource' do
          obj = { 'DependsOn' => %w(Route Dummy) }
          expect(@base_duplicator.send(:collect_depends, obj)).to eq(%w(Route Dummy))
        end

        it 'not return DependsOn value when template hasn\'t DependsOn entry' do
          obj = { Dummy: 'Route' }
          expect(@base_duplicator.send(:collect_depends, obj)).to eq([])
        end
      end

      describe 'collect' do
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
          allow(@base_duplicator).to receive(:collect_att).and_return('Subnet1')
          allow(@base_duplicator).to receive(:collect_depends).and_return('WaitCondition1')
        end

        it 'call collect_ref, collect_att, collect_depends' do
          expect(@base_duplicator).to receive(:collect_ref).with(@resource)
          expect(@base_duplicator).to receive(:collect_att).with(@resource)
          expect(@base_duplicator).to receive(:collect_depends).with(@resource)

          @base_duplicator.send(:collect, @resource)
        end

        it 'return resource that match from the resource to returned value' do
          collect_result =  @base_duplicator.send(:collect, @resource)

          expect(collect_result.include?('Instance1')).to be_truthy
          expect(collect_result.include?('Subnet1')).to be_truthy
          expect(collect_result.include?('WaitCondition1')).to be_truthy
          expect(collect_result.include?('FrontendEIP1')).to be_falsey
          expect(collect_result.include?('WebWaitHandle1')).to be_falsey
        end
      end

      describe '#change_ref' do
        it 'change Ref property in single hierarchy' do
          resource = {
            'Ref' => 'DummyProperty'
          }
          old_key = 'DummyProperty'
          new_key = 'TestProperty'

          @base_duplicator.send(:change_ref, resource, old_key, new_key)
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
          old_key = 'DummyProperty'
          new_key = 'TestProperty'

          @base_duplicator.send(:change_ref, resource, old_key, new_key)
          expect(resource['EIPAssociation1']['Properties']['NetworkInterfaceId']['Ref']).to eq('TestProperty')
        end
      end

      describe '#change_att' do
        it 'change Fn::GetAtt property in single hierarchy' do
          resource = {
            'Fn::GetAtt' => %w(DummyProperty AllocationId)
          }
          old_key = 'DummyProperty'
          new_key = 'TestProperty'

          @base_duplicator.send(:change_att, resource, old_key, new_key)
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
          old_key = 'DummyProperty'
          new_key = 'TestProperty'

          @base_duplicator.send(:change_att, resource, old_key, new_key)
          expect(resource['EIPAssociation1']['Properties']['AllocationId']['Fn::GetAtt']).to eq(%w(TestProperty AllocationId))
        end
      end

      describe '#change_depends' do
        it 'change DependsOn property if DependsOn property is string' do
          resource = { 'DependsOn' => 'dummy_key' }
          old_key = 'dummy_key'
          new_key = 'test_key'

          @base_duplicator.send(:change_depends, resource, old_key, new_key)
          expect(resource['DependsOn']).to eq('test_key')
        end

        it 'change DependsOn property if DependsOn property is array' do
          resource = { 'DependsOn' => %w(dummy_key dummy_depends) }
          old_key = 'dummy_key'
          new_key = 'test_key'

          @base_duplicator.send(:change_depends, resource, old_key, new_key)
          expect(resource['DependsOn']).to eq(%w(test_key dummy_depends))

          resource = { 'DependsOn' => %w(dummy_depends dummy_key) }

          @base_duplicator.send(:change_depends, resource, old_key, new_key)
          expect(resource['DependsOn']).to eq(%w(dummy_depends test_key))
        end
      end

      describe 'change' do
        before do
          allow(@base_duplicator).to receive(:change_ref)
          allow(@base_duplicator).to receive(:change_att)
          allow(@base_duplicator).to receive(:change_depends)

          @resource = {}
          @name_map = { old_name1: 'new_name1' }
        end

        it 'call change_ref, change_att, change_depends' do
          expect(@base_duplicator).to receive(:change_ref).with(@resource, :old_name1, 'new_name1')
          expect(@base_duplicator).to receive(:change_att).with(@resource, :old_name1, 'new_name1')
          expect(@base_duplicator).to receive(:change_depends).with(@resource, :old_name1, 'new_name1')

          @base_duplicator.send(:change, @resource, @name_map)
        end

        it 'call change_ref, change_att, change_depends for the size of name_map' do
          expect(@base_duplicator).to receive(:change_ref).twice
          expect(@base_duplicator).to receive(:change_att).twice
          expect(@base_duplicator).to receive(:change_depends).twice

          name_map = { old_name1: 'new_name1', old_name2: 'new_name2' }
          @base_duplicator.send(:change, @resource, name_map)
        end
      end
    end
  end
end
