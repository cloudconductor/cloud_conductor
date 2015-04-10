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
  module Adapters
    describe OpenStackAdapter do
      before do
        options = {
          entry_point: 'http://127.0.0.1:5000/',
          key: 'test_key',
          secret: 'test_secret',
          tenant_name: 'test_tenant'
        }
        @adapter = OpenStackAdapter.new options
      end

      it 'extend AbstractAdapter class' do
        expect(OpenStackAdapter.superclass).to eq(AbstractAdapter)
      end

      it 'has :openstack type' do
        expect(OpenStackAdapter::TYPE).to eq(:openstack)
      end

      describe '#create_stack' do
        before do
          allow(::Fog::Orchestration).to receive_message_chain(:new, :create_stack)

          @converter_stub = double('converter', convert: '{}')
          allow(CfnConverter).to receive(:create_converter).and_return(@converter_stub)
        end

        it 'execute without exception' do
          @adapter.create_stack 'stack_name', '{}', {}
        end

        it 'instantiate' do
          expect(::Fog::Orchestration).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_key',
              openstack_tenant: 'test_tenant'
            )

          @adapter.create_stack 'stack_name', '{}', {}
        end

        it 'call Fog::Orchestration#create_stack to create stack on openstack' do
          allow(::Fog::Orchestration).to receive_message_chain(:new) do
            double('newfog').tap do |newfog|
              expect(newfog).to receive(:create_stack).with(hash_including(stack_name: 'stack_name', template: '{}', parameters: {}))
            end
          end

          @adapter.create_stack 'stack_name', '{}', {}
        end

        it 'call OpenStackConverter to convert template before create stack' do
          expect(@converter_stub).to receive(:convert)

          @adapter.create_stack 'stack_name', '{}', {}
        end

        it 'use converted template to create stack' do
          converted_template = '{ dummy: "dummy" }'
          allow(@converter_stub).to receive(:convert).and_return converted_template

          heat_stub = double('heat')
          expect(heat_stub).to receive(:create_stack).with(hash_including(stack_name: 'stack_name', template: converted_template, parameters: {}))
          allow(::Fog::Orchestration).to receive(:new).and_return(heat_stub)

          @adapter.create_stack 'stack_name', '{}', {}
        end
      end

      describe '#update_stack' do
        before do
          allow(::Fog::Orchestration).to receive_message_chain(:new, :update_stack)

          @converter_stub = double('converter', convert: '{}')
          allow(CfnConverter).to receive(:create_converter).and_return(@converter_stub)
          allow(@adapter).to receive(:get_stack_id).and_return(1)
          @stack = double('stack', id: 1, stack_name: 'stack_name')
          allow(::Fog::Orchestration::OpenStack::Stack).to receive(:new).and_return(@stack)
        end

        it 'execute without exception' do
          @adapter.update_stack 'stack_name', '{}', {}
        end

        it 'instantiate' do
          expect(::Fog::Orchestration).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_key',
              openstack_tenant: 'test_tenant'
            )

          @adapter.update_stack 'stack_name', '{}', {}
        end

        it 'call Fog::Orchestration#update_stack to update stack on openstack' do
          allow(::Fog::Orchestration).to receive_message_chain(:new) do
            double('newfog').tap do |newfog|
              expect(newfog).to receive(:update_stack).with(@stack, hash_including(template: '{}', parameters: {}))
            end
          end

          @adapter.update_stack 'stack_name', '{}', {}
        end

        it 'call OpenStackConverter to convert template before update stack' do
          expect(@converter_stub).to receive(:convert)

          @adapter.update_stack 'stack_name', '{}', {}
        end

        it 'use converted template to create stack' do
          converted_template = '{ dummy: "dummy" }'
          allow(@converter_stub).to receive(:convert).and_return converted_template

          heat_stub = double('heat')
          expect(heat_stub).to receive(:update_stack).with(@stack, hash_including(template: converted_template, parameters: {}))
          allow(::Fog::Orchestration).to receive(:new).and_return(heat_stub)

          @adapter.update_stack 'stack_name', '{}', {}
        end
      end

      describe '#get_stack_status' do
        before do
          @stacks = {
            body: {
              stacks: [
                {
                  stack_name: 'abc',
                  stack_status: 'DUMMY'
                },
                {
                  stack_name: 'stack_name',
                  stack_status: 'TESTSTATUS'
                }
              ]
            }
          }

          allow(::Fog::Orchestration).to receive_message_chain(:new, :list_stack_data).and_return(@stacks)
        end

        it 'execute without exception' do
          @adapter.get_stack_status 'stack_name'
        end

        it 'instantiate' do
          expect(::Fog::Orchestration).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_key',
              openstack_tenant: 'test_tenant'
            )

          @adapter.get_stack_status 'stack_name'
        end

        it 'return stack status' do
          status = @adapter.get_stack_status 'stack_name'
          expect(status).to eq(:TESTSTATUS)
        end

        it 'return nil when target stack does not exist' do
          expect { @adapter.get_stack_status 'undefined_stack' }.to raise_error
        end
      end

      describe '#get_outputs' do
        before do
          @stacks = double(
            'stacks', :[] => double(
              'body', with_indifferent_access: double(
                'stacks', :[] => double(
                  'ary', find: double(
                    'stack', :[] => double(
                      'href', find: double(
                        'rel', :[] => 'http://dummy/'
                      )
                    )
                  )
                )
              )
            )
          )
          @heat = double('heat', list_stack_data: @stacks, auth_token: 'dummy_token')
          allow(::Fog::Orchestration).to receive_message_chain(:new).and_return(@heat)

          @request = double('request')
          allow(@request).to receive(:content_type=)
          allow(@request).to receive(:add_field)
          allow(Net::HTTP::Get).to receive_message_chain(:new).and_return(@request)

          @response = double('response')
          allow(@response).to receive(:body).and_return(
            {
              stack: {
                outputs: [
                  {
                    output_key: 'testkey',
                    output_value: 'testvalue'
                  }
                ]
              }
            }.to_json
          )
          allow(Net::HTTP).to receive(:start).and_return(@response)
        end

        it 'execute without exception' do
          @adapter.get_outputs 'stack_name'
        end

        it 'instantiate' do
          expect(::Fog::Orchestration).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_key',
              openstack_tenant: 'test_tenant'
            )

          @adapter.get_outputs 'stack_name'
        end

        it 'return outputs' do
          outputs = @adapter.get_outputs 'stack_name'
          outputs = outputs.with_indifferent_access
          expect(outputs[:testkey]).to eq('testvalue')
        end
      end

      describe '#availability_zones' do
        before do
          @availability_zones = [double('availability_zone', zone: 'nova'), double('availability_zone', zone: '')]
          allow(::Fog::Compute).to receive_message_chain(:new, :hosts).and_return(@availability_zones)
        end

        it 'execute without exception' do
          @adapter.availability_zones
        end

        it 'instantiate' do
          expect(::Fog::Compute).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_key',
              openstack_tenant: 'test_tenant'
            )

          @adapter.availability_zones
        end

        it 'return AvailabilityZone names' do
          availability_zones = @adapter.availability_zones
          expect(availability_zones).to eq(['nova', ''])
        end

        it 'return nil when target AvailabilityZone does not exist' do
          allow(@availability_zones).to receive(:map).and_return nil
          expect { @adapter.availability_zones }.to raise_error
        end
      end

      describe '#add_security_rules' do
        before do
          @template = <<-EOS
            {
              "Resources": {
                "SharedSecurityGroupInboundRule":{
                  "Type":"AWS::EC2::SecurityGroupIngress",
                  "Properties":{
                    "IpProtocol":"tcp",
                    "FromPort":"10050",
                    "ToPort":"10050",
                    "CidrIp":"10.0.0.0/16",
                    "GroupId":{"Ref":"SharedSecurityGroup"}
                  }
                }
              }
            }
          EOS
          @name = 'DummyStackName'
          @parameters = { SharedSecurityGroup: 'dummy_id' }.with_indifferent_access

          @rules = double(:security_group_rules)
          allow(@rules).to receive(:save)
          @nova = double(:nova)
          allow(@nova).to receive_message_chain(:security_group_rules, :new).and_return(@rules)
          @security_group = double(:security_group)
          allow(@security_group).to receive(:name).and_return('DummyStackName-DummySourceGroup-1234567890ab')
          allow(@security_group).to receive(:id).and_return('dummy_security_group_id')
          allow(@nova).to receive_message_chain(:security_groups, :all).and_return([@security_group])
          allow(::Fog::Compute).to receive(:new).and_return(@nova)
        end

        it 'execute without exception' do
          @adapter.add_security_rules(@name, @template, @parameters)
        end

        it 'instantiate a Fog Compute' do
          expect(::Fog::Compute).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_key',
              openstack_tenant: 'test_tenant'
            )

          @adapter.add_security_rules(@name, @template, @parameters)
        end

        it 'do nothing when AWS::EC2::SecurityGroupIngress in template is blank' do
          expect(@rules).not_to receive(:new)
          expect(@rules).not_to receive(:save)

          @template = '{ "Resources": {} }'
          @adapter.add_security_rules(@name, @template, @parameters)
        end

        it 'instantiate a security_group_rules in the case of CidrIp in template' do
          rule = {
            ip_protocol: 'tcp',
            from_port: '10050',
            to_port: '10050',
            parent_group_id: 'dummy_id',
            ip_range: { cidr: '10.0.0.0/16' }
          }.with_indifferent_access
          expect(@nova.security_group_rules).to receive(:new).with(rule)

          @adapter.add_security_rules(@name, @template, @parameters)
        end

        it 'instantiate a security_group_rules in the case of SourceSecurityGroupId in template' do
          rule = {
            ip_protocol: 'tcp',
            from_port: '10050',
            to_port: '10050',
            parent_group_id: 'dummy_security_group_id',
            group: 'dummy_security_group_id'
          }.with_indifferent_access
          expect(@nova.security_group_rules).to receive(:new).with(rule)

          template = <<-EOS
            {
              "Resources": {
                "SharedSecurityGroupInboundRule":{
                  "Type":"AWS::EC2::SecurityGroupIngress",
                  "Properties":{
                    "GroupId":{ "Ref": "DummySourceGroup" },
                    "IpProtocol":"tcp",
                    "FromPort":"10050",
                    "ToPort":"10050",
                    "CidrIp":"10.0.0.0/16",
                    "SourceSecurityGroupId":{"Ref":"DummySourceGroup"}
                  }
                }
              }
            }
          EOS
          @adapter.add_security_rules(@name, template, @parameters)
        end

        it 'call save to add security rule' do
          expect(@rules).to receive(:save)

          @adapter.add_security_rules(@name, @template, @parameters)
        end
      end

      describe '#destroy_stack' do
        before do
          @stack = double(:stack, stack_name: 'stack_name')
          @heat = double(:heat, stacks: [@stack])
          allow(@adapter).to receive(:heat).and_return(@heat)
        end

        it 'will request delete_stack API' do
          expect(@stack).to receive(:delete)
          @adapter.destroy_stack 'stack_name'
        end

        it 'doesn\'t raise any error when target stack was already deleted' do
          expect(@stack).not_to receive(:delete)
          @adapter.destroy_stack 'already_deleted_stack'
        end
      end
    end
  end
end
