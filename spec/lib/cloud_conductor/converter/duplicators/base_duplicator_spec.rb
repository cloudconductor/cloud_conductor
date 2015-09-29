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
      describe BaseDuplicator do
        before do
          @resources = {}
          @options = {}
          @base_duplicator = BaseDuplicator.new(@resources, @options)
        end

        describe '#replace_copied_properties' do
          it 'return the argument as it is' do
            resource = { 'Type' => 'AWS::EC2::Instance' }
            expect(@base_duplicator.send(:replace_copied_properties, resource)).to eq('Type' => 'AWS::EC2::Instance')
          end
        end

        describe '#copy' do
          it 'duplicate resource' do
            resources = {
              'webFrontendEIP' => {
                'Type' => 'AWS::EC2::EIP',
                'Properties' => {
                  'Domain' => 'vpc'
                }
              },
              'WebSecurityGroup' => {
                'Type' => 'AWS::EC2::SecurityGroup',
                'Metadata' => {
                  'Role' => 'web'
                },
                'Properties' => {
                  'VpcId' => { 'Ref' => 'VPC' },
                  'SecurityGroupIngress' => [
                    { 'IpProtocol' => 'tcp', 'FromPort' => '80', 'ToPort' => '80', 'CidrIp' => '0.0.0.0/0' }
                  ]
                }
              }
            }

            result_resource = {
              'webFrontendEIP' => {
                'Type' => 'AWS::EC2::EIP',
                'Properties' => {
                  'Domain' => 'vpc'
                }
              },
              'WebSecurityGroup' => {
                'Type' => 'AWS::EC2::SecurityGroup',
                'Metadata' => {
                  'Role' => 'web'
                },
                'Properties' => {
                  'VpcId' => { 'Ref' => 'VPC' },
                  'SecurityGroupIngress' => [
                    { 'IpProtocol' => 'tcp', 'FromPort' => '80', 'ToPort' => '80', 'CidrIp' => '0.0.0.0/0' }
                  ]
                }
              },
              'webFrontendEIP2' => {
                'Type' => 'AWS::EC2::EIP',
                'Properties' => {
                  'Domain' => 'vpc'
                },
                'Metadata' => {
                  'Copied' => true
                }
              }
            }

            options = {
              AvailabilityZone: ['ap-southeast-2a', 'ap-southeast-2b'],
              CopyNum: 2,
              Role: 'web'
            }

            @base_duplicator = BaseDuplicator.new(resources, options)
            resources.merge! @base_duplicator.copy('webFrontendEIP', {}, options)

            expect(resources).to eq(result_resource)
          end
        end

        describe '#copyable?' do
          it 'return true when resource exist in the COPYABLE_RESOURCES ' do
            resource = { 'Type' => 'AWS::EC2::Instance' }
            expect(@base_duplicator.send(:copyable?, resource)).to be_truthy
          end

          it 'return true when resource not exist in the COPYABLE_RESOURCES ' do
            resource = { 'Type' => 'AWS::EC2::VPC' }
            expect(@base_duplicator.send(:copyable?, resource)).to be_falsey
          end
        end

        describe '#already_copied?' do
          it 'return true when copied_resource_mapping_table keys contained source_name' do
            copied_resource_mapping_table = {
              'original_name' => 'copy_name'
            }
            source_name = 'original_name'

            expect(@base_duplicator.send(:already_copied?, source_name, copied_resource_mapping_table)).to be_truthy
          end

          it 'return true when copied_resource_mapping_table values contained source_name' do
            copied_resource_mapping_table = {
              'original_name' => 'copy_name'
            }
            source_name = 'copy_name'

            expect(@base_duplicator.send(:already_copied?, source_name, copied_resource_mapping_table)).to be_truthy
          end

          it 'return true when resource contained copied in metadata' do
            copied_resource_mapping_table = {
              'original_name' => 'copy_name'
            }
            source_name = 'dummy_name'
            resources = {
              'dummy_name' => {
                'Type' => 'AWS::EC2::Instance',
                'Properties' => {
                  'Domain' => 'vpc'
                },
                'Metadata' => {
                  'Copied' => true
                }
              }
            }
            base_duplicator = BaseDuplicator.new(resources, @options)

            expect(base_duplicator.send(:already_copied?, source_name, copied_resource_mapping_table)).to be_truthy
          end

          it 'return false when does not match to any' do
            copied_resource_mapping_table = {
              'original_name' => 'copy_name'
            }
            source_name = 'dummy_name'
            resources = {
              'dummy_name' => {
                'Type' => 'AWS::EC2::Instance',
                'Properties' => {
                  'Domain' => 'vpc'
                }
              }
            }
            base_duplicator = BaseDuplicator.new(resources, @options)

            expect(base_duplicator.send(:already_copied?, source_name, copied_resource_mapping_table)).to be_falsey
          end
        end

        describe '#add_copied_flag' do
          it 'add flag for checking whether resource has already been copied in metadata' do
            resource = {
              'Type' => 'AWS::EC2::EIP',
              'Properties' => {
                'Domain' => 'vpc'
              }
            }

            result_resource = {
              'Type' => 'AWS::EC2::EIP',
              'Properties' => {
                'Domain' => 'vpc'
              },
              'Metadata' => {
                'Copied' => true
              }
            }

            @base_duplicator.send(:add_copied_flag, resource)

            expect(resource).to eq(result_resource)
          end
        end

        describe '#post_copy' do
          it 'call replace_associated_resources, replace_copied_properties, add_copied_flag methods' do
            copied_resource_mapping_table = {
              'original_name' => 'copy_name'
            }
            resource = {
              'Type' => 'AWS::EC2::EIP',
              'Properties' => {
                'Domain' => 'vpc'
              }
            }

            allow(@base_duplicator).to receive(:replace_associated_resources).and_return(resource)
            allow(@base_duplicator).to receive(:replace_copied_properties).and_return(resource)
            allow(@base_duplicator).to receive(:add_copied_flag).and_return(resource)

            expect(@base_duplicator).to receive(:replace_associated_resources).with(resource, copied_resource_mapping_table)
            expect(@base_duplicator).to receive(:replace_copied_properties).with(resource)
            expect(@base_duplicator).to receive(:add_copied_flag).with(resource)
            @base_duplicator.send(:post_copy, copied_resource_mapping_table, resource)
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

        describe '#contain_ref?' do
          it 'return true when template has Ref entry with specified resource' do
            resource = { Ref: 'Route' }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_truthy
          end

          it 'return true when deep hash has Ref entry' do
            resource = { Dummy: { Ref: 'Route' } }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_truthy
          end

          it 'return true when deep array has Ref entry' do
            resource = { Dummy: [{ Ref: 'Route' }] }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_truthy
          end

          it 'return false when template hasn\'t Ref entry' do
            resource = { Dummy: [{ Hoge: 'Route' }] }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_falsey
          end

          it 'return false when template hasn\'t Ref entry with specified resource' do
            resource = { Dummy: [{ Ref: 'Hoge' }] }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_falsey
          end

          it 'return true when template has GetAtt entry with specified resource' do
            resource = { :'Fn::GetAtt' => %w(Route Dummy) }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_truthy
          end

          it 'return true when deep hash has GetAtt entry' do
            resource = { Dummy: { :'Fn::GetAtt' => %w(Route Dummy) } }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_truthy
          end

          it 'return true when deep array has GetAtt entry' do
            resource = { Dummy: [{ :'Fn::GetAtt' => %w(Route Dummy) }] }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_truthy
          end

          it 'return false when template hasn\'t Ref entry' do
            resource = { Dummy: [{ Dummy: %w(Route Dummy) }] }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_falsey
          end

          it 'return false when template hasn\'t Ref entry with specified resource' do
            resource = { Dummy: [{ :'Fn::GetAtt' => %w(Hoge Dummy) }] }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_falsey
          end

          it 'return true when template has DependsOn entry with specified resource' do
            resource = { DependsOn: 'Route' }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_truthy
          end

          it 'return true when template has DependsOn entry with specified resource' do
            resource = { DependsOn: %w(Route dummy) }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_truthy
          end

          it 'return false when template hasn\'t DependsOn entry' do
            resource = { Dummy: 'Route' }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_falsey
          end

          it 'return false when template hasn\'t DependsOn entry with specified resource' do
            resource = { DependsOn: 'Hoge' }
            expect(@base_duplicator.send(:contain_name_in_element?, 'Route', resource)).to be_falsey
          end
        end

        describe '#contain?' do
          before do
            @contain_sample = @base_duplicator.send(:contain?, 'SourceName')
          end

          it 'return lambda' do
            expect(@contain_sample.class).to eq(Proc)
            expect(@contain_sample.lambda?).to be_truthy
          end

          it 'return false when resource has not contain source_name' do
            resource = { Dummy: 'Sample' }
            expect(@contain_sample.call('Key', resource)).to be_falsey
          end

          it 'return true when resource has contain source_name ' do
            resource = { Ref: 'SourceName' }
            expect(@contain_sample.call('Key', resource)).to be_truthy
          end
        end

        describe '#collect_names_associated_with' do
          it 'return Ref value when template has Ref entry with specified resource' do
            resource = { 'Ref' => 'Route' }
            expect(@base_duplicator.send(:collect_names_associated_with, resource)).to eq(['Route'])
          end

          it 'return Ref value when deep hash has Ref entry' do
            resource = { Dummy: { 'Ref' => 'Route' } }
            expect(@base_duplicator.send(:collect_names_associated_with, resource)).to eq(['Route'])
          end

          it 'return Ref value when deep array has Ref entry' do
            resource = { Dummy: [{ 'Ref' => 'Route' }] }
            expect(@base_duplicator.send(:collect_names_associated_with, resource)).to eq(['Route'])
          end

          it 'not return Ref value when template hasn\'t Ref entry' do
            resource = { Dummy: [{ Hoge: 'Route' }] }
            expect(@base_duplicator.send(:collect_names_associated_with, resource)).to eq([])
          end

          it 'return GetAtt value when template has GetAtt entry with specified resource' do
            obj = { 'Fn::GetAtt' => %w(Route Dummy) }
            expect(@base_duplicator.send(:collect_names_associated_with, obj)).to eq(['Route'])
          end

          it 'return GetAtt value when deep hash has GetAtt entry' do
            obj = { Dummy: { 'Fn::GetAtt' => %w(Route Dummy) } }
            expect(@base_duplicator.send(:collect_names_associated_with, obj)).to eq(['Route'])
          end

          it 'return GetAtt value when deep array has GetAtt entry' do
            obj = { Dummy: [{ 'Fn::GetAtt' => %w(Route Dummy) }] }
            expect(@base_duplicator.send(:collect_names_associated_with, obj)).to eq(['Route'])
          end

          it 'not return GetAtt value when template hasn\'t Ref entry' do
            obj = { Dummy: [{ Dummy: %w(Route Dummy) }] }
            expect(@base_duplicator.send(:collect_names_associated_with, obj)).to eq([])
          end

          it 'return DependsOn value when template has DependsOn entry with specified resource' do
            obj = { 'DependsOn' => 'Route' }
            expect(@base_duplicator.send(:collect_names_associated_with, obj)).to eq(['Route'])
          end

          it 'return DependsOn value when template has DependsOn entry with specified resource' do
            obj = { 'DependsOn' => %w(Route Dummy) }
            expect(@base_duplicator.send(:collect_names_associated_with, obj)).to eq(%w(Route Dummy))
          end

          it 'not return DependsOn value when template hasn\'t DependsOn entry' do
            obj = { Dummy: 'Route' }
            expect(@base_duplicator.send(:collect_names_associated_with, obj)).to eq([])
          end
        end

        describe 'collect_resources_associated_with' do
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
            allow(@base_duplicator).to receive(:collect_names_associated_with).and_return(%w(Instance1 Subnet1 WaitCondition1))
          end

          it 'call collect_ref, collect_get_att, collect_depends_on' do
            expect(@base_duplicator).to receive(:collect_names_associated_with).with(@resource)

            @base_duplicator.send(:collect_resources_associated_with, @resource)
          end

          it 'return resource that match from the resource to returned value' do
            collect_result =  @base_duplicator.send(:collect_resources_associated_with, @resource)

            expect(collect_result.include?('Instance1')).to be_truthy
            expect(collect_result.include?('Subnet1')).to be_truthy
            expect(collect_result.include?('WaitCondition1')).to be_truthy
            expect(collect_result.include?('FrontendEIP1')).to be_falsey
            expect(collect_result.include?('WebWaitHandle1')).to be_falsey
          end
        end

        describe '#replace_ref' do
          it 'replace Ref property in single hierarchy' do
            resource = {
              'Ref' => 'DummyProperty'
            }
            original_name = 'DummyProperty'
            copy_name = 'TestProperty'

            @base_duplicator.send(:replace_ref, original_name, copy_name, resource)
            expect(resource['Ref']).to eq('TestProperty')
          end

          it 'replace Ref property in single hierarchy' do
            resource = {
              'EIPAssociation1' => {
                'Type' => 'AWS::EC2::EIPAssociation',
                'Properties' => {
                  'NetworkInterfaceId' => { 'Ref' => 'DummyProperty' }
                }
              }
            }
            original_name = 'DummyProperty'
            copy_name = 'TestProperty'

            @base_duplicator.send(:replace_ref, original_name, copy_name, resource)
            expect(resource['EIPAssociation1']['Properties']['NetworkInterfaceId']['Ref']).to eq('TestProperty')
          end
        end

        describe '#replace_get_att' do
          it 'replace Fn::GetAtt property in single hierarchy' do
            resource = {
              'Fn::GetAtt' => %w(DummyProperty AllocationId)
            }
            original_name = 'DummyProperty'
            copy_name = 'TestProperty'

            @base_duplicator.send(:replace_get_att, original_name, copy_name, resource)
            expect(resource['Fn::GetAtt']).to eq(%w(TestProperty AllocationId))
          end

          it 'replace Fn::GetAtt property in multi hierarchy' do
            resource = {
              'EIPAssociation1' => {
                'Type' => 'AWS::EC2::EIPAssociation',
                'Properties' => {
                  'AllocationId' => { 'Fn::GetAtt' => %w(DummyProperty AllocationId) },
                  'NetworkInterfaceId' => { 'Ref' => 'WebNetworkInterface1' }
                }
              }
            }
            original_name = 'DummyProperty'
            copy_name = 'TestProperty'

            @base_duplicator.send(:replace_get_att, original_name, copy_name, resource)
            expect(resource['EIPAssociation1']['Properties']['AllocationId']['Fn::GetAtt']).to eq(%w(TestProperty AllocationId))
          end
        end

        describe '#replace_depends_on' do
          it 'replace DependsOn property if DependsOn property is string' do
            resource = { 'DependsOn' => 'dummy_name' }
            original_name = 'dummy_name'
            copy_name = 'test_name'

            @base_duplicator.send(:replace_depends_on, original_name, copy_name, resource)
            expect(resource['DependsOn']).to eq('test_name')
          end

          it 'replace DependsOn property if DependsOn property is array' do
            resource = { 'DependsOn' => %w(dummy_name dummy_depends) }
            original_name = 'dummy_name'
            copy_name = 'test_name'

            @base_duplicator.send(:replace_depends_on, original_name, copy_name, resource)
            expect(resource['DependsOn']).to eq(%w(test_name dummy_depends))

            resource = { 'DependsOn' => %w(dummy_depends dummy_name) }

            @base_duplicator.send(:replace_depends_on, original_name, copy_name, resource)
            expect(resource['DependsOn']).to eq(%w(dummy_depends test_name))
          end
        end

        describe 'replace_associated_resources' do
          before do
            allow(@base_duplicator).to receive(:replace_ref)
            allow(@base_duplicator).to receive(:replace_get_att)
            allow(@base_duplicator).to receive(:replace_depends_on)

            @resource = {}
            @copied_resource_mapping_table = { original_name1: 'copy_name1' }
          end

          it 'call replace_ref, replace_get_att, replace_depends_on' do
            expect(@base_duplicator).to receive(:replace_ref).with(:original_name1, 'copy_name1', @resource)
            expect(@base_duplicator).to receive(:replace_get_att).with(:original_name1, 'copy_name1', @resource)
            expect(@base_duplicator).to receive(:replace_depends_on).with(:original_name1, 'copy_name1', @resource)

            @base_duplicator.send(:replace_associated_resources, @resource, @copied_resource_mapping_table)
          end

          it 'call replace_ref, replace_get_att, replace_depends_on for the size of copied_resource_mapping_table' do
            expect(@base_duplicator).to receive(:replace_ref).twice
            expect(@base_duplicator).to receive(:replace_get_att).twice
            expect(@base_duplicator).to receive(:replace_depends_on).twice

            copied_resource_mapping_table = { original_name1: 'copy_name1', original_name2: 'copy_name2' }
            @base_duplicator.send(:replace_associated_resources, @resource, copied_resource_mapping_table)
          end
        end
      end
    end
  end
end
