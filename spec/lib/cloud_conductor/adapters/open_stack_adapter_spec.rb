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
        @adapter = OpenStackAdapter.new
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

          @options = {}
          @options[:entry_point] = 'http://127.0.0.1:5000/'
          @options[:key] = 'test_user'
          @options[:secret] = 'test_secret'
          @options[:tenant_name] = 'test_tenant'

          @converter_stub = double('converter', convert: '{}')
          allow(CfnConverter).to receive(:create_converter).and_return(@converter_stub)
        end

        it 'execute without exception' do
          @adapter.create_stack 'stack_name', '{}', {}, {}
        end

        it 'instantiate' do
          @options[:dummy] = 'dummy'

          expect(::Fog::Orchestration).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_user',
              openstack_tenant: 'test_tenant'
            )

          @adapter.create_stack 'stack_name', '{}', {}, @options
        end

        it 'call Fog::Orchestration#create_stack to create stack on openstack' do
          allow(::Fog::Orchestration).to receive_message_chain(:new) do
            double('newfog').tap do |newfog|
              expect(newfog).to receive(:create_stack).with('stack_name', hash_including(template: '{}', parameters: {}))
            end
          end

          @adapter.create_stack 'stack_name', '{}', {}, @options
        end

        it 'call OpenStackConverter to convert template before create stack' do
          expect(@converter_stub).to receive(:convert)

          @adapter.create_stack 'stack_name', '{}', {}, @options
        end

        it 'use converted template to create stack' do
          converted_template = '{ dummy: "dummy" }'
          allow(@converter_stub).to receive(:convert).and_return converted_template

          orc_stub = double('orc')
          expect(orc_stub).to receive(:create_stack).with('stack_name', hash_including(template: converted_template, parameters: {}))
          allow(::Fog::Orchestration).to receive(:new).and_return(orc_stub)

          @adapter.create_stack 'stack_name', '{}', {}, @options
        end
      end

      describe '#get_stack_status' do
        before do
          @options = {}
          @options[:entry_point] = 'http://127.0.0.1:5000/'
          @options[:key] = 'test_user'
          @options[:secret] = 'test_secret'
          @options[:tenant_name] = 'test_tenant'

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

          allow(::Fog::Orchestration).to receive_message_chain(:new, :list_stacks).and_return(@stacks)
        end

        it 'execute without exception' do
          @adapter.get_stack_status 'stack_name', @options
        end

        it 'instantiate' do
          @options[:dummy] = 'dummy'

          expect(::Fog::Orchestration).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_user',
              openstack_tenant: 'test_tenant'
            )

          @adapter.get_stack_status 'stack_name', @options
        end

        it 'return stack status' do
          status = @adapter.get_stack_status 'stack_name', @options
          expect(status).to eq(:TESTSTATUS)
        end

        it 'return nil when target stack does not exist' do
          expect { @adapter.get_stack_status 'undefined_stack', @options }.to raise_error
        end
      end

      describe '#get_outputs' do
        before do
          @options = {}
          @options[:entry_point] = 'http://127.0.0.1:5000/'
          @options[:key] = 'test_user'
          @options[:secret] = 'test_secret'
          @options[:tenant_name] = 'test_tenant'

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
          @orc = double('orc', list_stacks: @stacks, auth_token: 'dummy_token')
          allow(::Fog::Orchestration).to receive_message_chain(:new).and_return(@orc)

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
          @adapter.get_outputs 'stack_name', @options
        end

        it 'instantiate' do
          @options[:dummy] = 'dummy'

          expect(::Fog::Orchestration).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_user',
              openstack_tenant: 'test_tenant'
            )

          @adapter.get_outputs 'stack_name', @options
        end

        it 'return outputs' do
          outputs = @adapter.get_outputs 'stack_name', @options
          outputs = outputs.with_indifferent_access
          expect(outputs[:testkey]).to eq('testvalue')
        end
      end

      describe '#add_security_rule' do
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
          @options = {}
          @options[:entry_point] = 'http://127.0.0.1:5000/'
          @options[:key] = 'dummy_key'
          @options[:secret] = 'dummy_secret'
          @options[:tenant_name] = 'dummy_tenant'

          @rules = double(:security_group_rules)
          allow(@rules).to receive(:save)
          @compute = double(:compute)
          allow(@compute).to receive_message_chain(:security_group_rules, :new).and_return(@rules)
          @security_group = double(:security_group)
          allow(@security_group).to receive(:name).and_return('DummyStackName-DummySourceGroup-1234567890ab')
          allow(@security_group).to receive(:id).and_return('dummy_security_group_id')
          allow(@compute).to receive_message_chain(:security_groups, :all).and_return([@security_group])
          allow(::Fog::Compute).to receive(:new).and_return(@compute)
        end

        it 'execute without exception' do
          @adapter.add_security_rule(@name, @template, @parameters, @options)
        end

        it 'instantiate a Fog Compute' do
          expect(::Fog::Compute).to receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'dummy_secret',
              openstack_username: 'dummy_key',
              openstack_tenant: 'dummy_tenant'
            )

          @adapter.add_security_rule(@name, @template, @parameters, @options)
        end

        it 'do nothing when SharedSecurityGroup in parameters is blank' do
          expect(::Fog::Compute).not_to receive(:new)
          expect(@rules).not_to receive(:new)
          expect(@rules).not_to receive(:save)

          @parameters = {}
          @adapter.add_security_rule(@name, @template, @parameters, @options)
        end

        it 'do nothing when AWS::EC2::SecurityGroupIngress in template is blank' do
          expect(@rules).not_to receive(:new)
          expect(@rules).not_to receive(:save)

          @template = {}
          @adapter.add_security_rule(@name, @template, @parameters, @options)
        end

        it 'instantiate a security_group_rules in the case of CidrIp in template' do
          rule = {
            ip_protocol: 'tcp',
            from_port: '10050',
            to_port: '10050',
            parent_group_id: 'dummy_id',
            ip_range: { cidr: '10.0.0.0/16' }
          }.with_indifferent_access
          expect(@compute.security_group_rules).to receive(:new).with(rule)

          @adapter.add_security_rule(@name, @template, @parameters, @options)
        end

        it 'instantiate a security_group_rules in the case of SourceSecurityGroupId in template' do
          rule = {
            ip_protocol: 'tcp',
            from_port: '10050',
            to_port: '10050',
            parent_group_id: 'dummy_id',
            group: 'dummy_security_group_id'
          }.with_indifferent_access
          expect(@compute.security_group_rules).to receive(:new).with(rule)

          template = <<-EOS
{
  "Resources": {
    "SharedSecurityGroupInboundRule":{
      "Type":"AWS::EC2::SecurityGroupIngress",
      "Properties":{
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
          @adapter.add_security_rule(@name, template, @parameters, @options)
        end

        it 'call save to add security rule' do
          expect(@rules).to receive(:save)

          @adapter.add_security_rule(@name, @template, @parameters, @options)
        end
      end

      describe '#destroy_stack' do
        before do
          @stacks = {
            stacks: [
              {
                stack_name: 'stack_name',
                id: 'stack_id'
              }
            ]
          }
          @orc = double(:orc, list_stacks: { body: @stacks }, delete_stack: nil)
          allow(@adapter).to receive(:create_orchestration).and_return(@orc)
        end

        it 'will request delete_stack API' do
          expect(@orc).to receive(:delete_stack).with('stack_name', :stack_id)
          @adapter.destroy_stack 'stack_name'
        end

        it 'doesn\'t raise any error when target stack was already deleted' do
          @adapter.destroy_stack 'already_deleted_stack'
        end
      end
    end
  end
end
