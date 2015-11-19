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
          allow(@adapter).to receive_message_chain(:heat, :create_stack)

          @converter_stub = double('converter', convert: '{}')
          allow(CfnConverter).to receive(:create_converter).and_return(@converter_stub)
        end

        it 'execute without exception' do
          @adapter.create_stack 'stack_name', '{}', {}
        end

        it 'call heat#create_stack to create stack on openstack' do
          allow(@adapter).to receive(:heat) do
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
          allow(@adapter).to receive(:heat).and_return(heat_stub)

          @adapter.create_stack 'stack_name', '{}', {}
        end
      end

      describe '#update_stack' do
        before do
          allow(@adapter).to receive_message_chain(:heat, :update_stack)

          @converter_stub = double('converter', convert: '{}')
          allow(CfnConverter).to receive(:create_converter).and_return(@converter_stub)
          allow(@adapter).to receive(:get_stack_id).and_return(1)
          @stack = double('stack', id: 1, stack_name: 'stack_name')
          allow(::Fog::Orchestration::OpenStack::Stack).to receive(:new).and_return(@stack)
        end

        it 'execute without exception' do
          @adapter.update_stack 'stack_name', '{}', {}
        end

        it 'call heat#update_stack to update stack on openstack' do
          allow(@adapter).to receive(:heat) do
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
          allow(@adapter).to receive(:heat).and_return(heat_stub)

          @adapter.update_stack 'stack_name', '{}', {}
        end
      end

      describe '#get_stack_id' do
        before do
          @stacks = [
            double('stack', stack_name: 'abc', id: '1'),
            double('stack', stack_name: 'stack_name', id: '2')
          ]

          allow(@adapter).to receive_message_chain(:heat, :stacks).and_return(@stacks)
        end

        it 'execute without exception' do
          @adapter.get_stack_id 'stack_name'
        end

        it 'return stack status' do
          id = @adapter.get_stack_id 'stack_name'
          expect(id).to eq('2')
        end

        it 'return nil when target stack does not exist' do
          expect { @adapter.get_stack_id 'undefined_stack' }.to raise_error(RuntimeError)
        end
      end

      describe '#get_stack_status' do
        before do
          @stacks = [
            double('stack', stack_name: 'abc', stack_status: 'TEST'),
            double('stack', stack_name: 'stack_name', stack_status: 'DUMMY')
          ]

          allow(@adapter).to receive_message_chain(:heat, :stacks).and_return(@stacks)
        end

        it 'execute without exception' do
          @adapter.get_stack_status 'stack_name'
        end

        it 'return stack status' do
          status = @adapter.get_stack_status 'stack_name'
          expect(status).to eq(:DUMMY)
        end

        it 'return nil when target stack does not exist' do
          expect { @adapter.get_stack_status 'undefined_stack' }.to raise_error(RuntimeError)
        end
      end

      describe '#get_stack_events' do
        before do
          event = double('event', event_time: '2015-01-01T00:00:00Z', resource_status: 'CREATE_FAILED', logical_resource_id: 'dummy', resource_status_reason: 'dummy error')

          @stacks = [
            double('stack', stack_name: 'abc', events: ['dummy']),
            double('stack', stack_name: 'stack_name', events: [event])
          ]

          allow(::Fog::Orchestration).to receive_message_chain(:new, :stacks).and_return(@stacks)
        end

        it 'execute without exception' do
          @adapter.get_stack_events 'stack_name'
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

          @adapter.get_stack_events 'stack_name'
        end

        it 'return stack events' do
          expected_events = [
            {
              timestamp: '2015-01-01T09:00:00+09:00',
              resource_status: 'CREATE_FAILED',
              resource_type: nil,
              logical_resource_id: 'dummy',
              resource_status_reason: 'dummy error'
            }
          ]
          events = @adapter.get_stack_events 'stack_name'
          expect(events).to eq(expected_events)
        end

        it 'return nil when target stack does not exist' do
          expect { @adapter.get_stack_events 'undefined_stack' }.to raise_error(RuntimeError)
        end
      end

      describe '#get_outputs' do
        before do
          @stacks = [
            double('stack', stack_name: 'abc', links: [{ 'rel' => 'dummy', 'href' => 'http://dummy/' }]),
            double('stack', stack_name: 'stack_name', links: [{ 'rel' => 'self', 'href' => 'http://example/' }])
          ]
          @heat = double('heat', stacks: @stacks, auth_token: 'dummy_token')
          allow(@adapter).to receive(:heat).and_return(@heat)

          @request = double('request')
          allow(@request).to receive(:content_type=)
          allow(@request).to receive(:add_field)
          allow(Net::HTTP::Get).to receive(:new).and_return(@request)

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

        it 'return outputs' do
          outputs = @adapter.get_outputs 'stack_name'
          outputs = outputs.with_indifferent_access
          expect(outputs[:testkey]).to eq('testvalue')
        end
      end

      describe '#availability_zones' do
        it 'return AvailabilityZone names' do
          @availability_zones = [double('availability_zone', zone: 'nova'), double('availability_zone', zone: '')]
          allow(@adapter).to receive_message_chain(:nova, :hosts).and_return(@availability_zones)
          expect(@adapter.availability_zones).to eq(['nova', ''])
        end

        it 'return empty array when AvailabilityZones does not exist' do
          @availability_zones = []
          allow(@adapter).to receive_message_chain(:nova, :hosts).and_return(@availability_zones)
          expect(@adapter.availability_zones).to be_empty
        end
      end

      describe '#add_security_rules' do
        before do
          allow(@adapter).to receive(:add_security_rule)

          @name = 'DummyStackName'
          @template = <<-EOS
            {
              "Resources": {
                "SharedSecurityGroupInboundRule": {
                  "Type": "AWS::EC2::SecurityGroupIngress",
                  "Properties": {
                    "IpProtocol": "tcp",
                    "FromPort": "10050",
                    "ToPort": "10050",
                    "CidrIp": "10.0.0.0/16",
                    "GroupId": {
                      "Ref":"SharedSecurityGroup"
                    }
                  }
                }
              }
            }
          EOS
        end

        it 'execute without exception' do
          @adapter.add_security_rules(@name, @template, {})
        end

        it 'call add_security_rule' do
          expected_arguments = {
            IpProtocol: 'tcp',
            FromPort: '10050',
            ToPort: '10050',
            CidrIp: '10.0.0.0/16',
            GroupId: {
              Ref: 'SharedSecurityGroup'
            }
          }

          expect(@adapter).to receive(:add_security_rule).with('DummyStackName', expected_arguments, {})
          @adapter.add_security_rules(@name, @template, {})
        end
      end

      describe '#add_security_rule' do
        before do
          new_rule = double(:rule)
          allow(new_rule).to receive(:save)
          @security_group_rules = double(:security_group_rules)
          allow(@security_group_rules).to receive(:new).and_return(new_rule)
          allow(@adapter).to receive_message_chain(:nova, :security_group_rules).and_return(@security_group_rules)
          allow(@adapter).to receive(:get_security_group_id).and_return('dummy_security_group_id')

          @name = 'DummyStackName'
          @properties = {
            IpProtocol: 'tcp',
            FromPort: '10050',
            ToPort: '10050',
            CidrIp: '10.0.0.0/16',
            GroupId: {
              Ref: 'SharedSecurityGroup'
            },
            SourceSecurityGroupId: {
              Ref: 'SourceSecurityGroup'
            }
          }
          @parameters = { SharedSecurityGroup: 'dummy_id' }.with_indifferent_access
        end

        it 'execute without exception' do
          @adapter.add_security_rule(@name, @properties, @parameters)
        end

        it 'if properties include SharedSecurityGroup' do
          expected_rule = {
            ip_protocol: 'tcp',
            from_port: '10050',
            to_port: '10050',
            parent_group_id: 'dummy_id',
            ip_range: { cidr: '10.0.0.0/16' }
          }.with_indifferent_access

          properties = {
            IpProtocol: 'tcp',
            FromPort: '10050',
            ToPort: '10050',
            CidrIp: '10.0.0.0/16',
            GroupId: {
              Ref: 'SharedSecurityGroup'
            }
          }

          expect(@security_group_rules).to receive(:new).with(expected_rule)
          @adapter.add_security_rule(@name, properties, @parameters)
        end

        it 'call get_security_group_id if properties not include SharedSecurityGroup' do
          expected_rule = {
            ip_protocol: 'tcp',
            from_port: '10050',
            to_port: '10050',
            parent_group_id: 'dummy_security_group_id',
            group: 'dummy_security_group_id'
          }.with_indifferent_access

          expect(@security_group_rules).to receive(:new).with(expected_rule)
          @adapter.add_security_rule(@name, @properties, {})
        end

        it 'if properties include SharedSecurityGroupId' do
          expected_rule = {
            ip_protocol: 'tcp',
            from_port: '10050',
            to_port: '10050',
            parent_group_id: 'dummy_id',
            group: 'dummy_security_group_id'
          }.with_indifferent_access

          expect(@security_group_rules).to receive(:new).with(expected_rule)
          @adapter.add_security_rule(@name, @properties, @parameters)
        end

        it 'if properties not include SharedSecurityGroupId' do
          expected_rule = {
            ip_protocol: 'tcp',
            from_port: '10050',
            to_port: '10050',
            parent_group_id: 'dummy_id',
            ip_range: { cidr: '10.0.0.0/16' }
          }.with_indifferent_access

          properties = {
            IpProtocol: 'tcp',
            FromPort: '10050',
            ToPort: '10050',
            CidrIp: '10.0.0.0/16',
            GroupId: {
              Ref: 'SharedSecurityGroup'
            }
          }

          expect(@security_group_rules).to receive(:new).with(expected_rule)
          @adapter.add_security_rule(@name, properties, @parameters)
        end
      end

      describe '#get_security_group_id' do
        before do
          security_groups = [
            double('security_group', name: 'test_name1-1234567890ab', id: '1'),
            double('security_group', name: 'test_name2-1234567890ab', id: '2')
          ]
          allow(@adapter).to receive_message_chain(:nova, :security_groups, :all).and_return(security_groups)
        end

        it 'execute without exception' do
          @adapter.get_security_group_id 'test_name1'
        end

        it 'return stack status' do
          id = @adapter.get_security_group_id 'test_name2'
          expect(id).to eq('2')
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

      describe '#destroy_image' do
        before do
          @image = double('image', status: 'ACTIVE')
          allow(@adapter).to receive_message_chain(:nova, :images, :get).and_return(@image)
          allow(@image).to receive(:destroy)
        end

        it 'execute without exception' do
          @adapter.destroy_image 'dummy_image'
        end

        it 'call destroy to delete created image on openstack' do
          expect(@image).to receive(:destroy)

          @adapter.destroy_image 'dummy_image'
        end
      end

      describe '#flavor' do
        before do
          @flavor = double(:flavor, name: 'dummy_flavor_name')
          @nova = double(:nova, flavors: [@flavor])
          allow(::Fog::Compute).to receive(:new).and_return(@nova)
        end

        it 'return flavor id' do
          expect(@adapter.flavor 'dummy_flavor_name').to eq(@flavor)
        end
      end

      describe '#heat' do
        it 'call Fog::Orchestration with necessary options' do
          allow(::Fog::Orchestration).to receive(:new)

          expected_arguments = {
            provider: :OpenStack,
            openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
            openstack_api_key: 'test_secret',
            openstack_username: 'test_key',
            openstack_tenant: 'test_tenant'
          }
          expect(::Fog::Orchestration).to receive(:new).with(expected_arguments)
          @adapter.send(:heat)
        end
      end

      describe '#nova' do
        it 'call Fog::Compute necessary options' do
          allow(::Fog::Compute).to receive(:new)

          expected_arguments = {
            provider: :OpenStack,
            openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
            openstack_api_key: 'test_secret',
            openstack_username: 'test_key',
            openstack_tenant: 'test_tenant'
          }
          expect(::Fog::Compute).to receive(:new).with(expected_arguments)
          @adapter.send(:nova)
        end
      end
    end
  end
end
