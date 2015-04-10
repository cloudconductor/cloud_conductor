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
    describe AWSAdapter do
      before do
        @adapter = AWSAdapter.new
      end

      it 'extend AbstractAdapter class' do
        expect(AWSAdapter.superclass).to eq(AbstractAdapter)
      end

      it 'has :aws type' do
        expect(AWSAdapter::TYPE).to eq(:aws)
      end

      describe '#create_stack' do
        before do
          allow(AWS::CloudFormation).to receive_message_chain(:new, :stacks, :create)

          @options = {}
          @options[:key] = '1234567890abcdef'
          @options[:secret] = 'abcdef1234567890'
        end

        it 'execute without exception' do
          @adapter.create_stack 'stack_name', '{}', {}, {}
        end

        it 'set credentials for aws-sdk' do
          @options[:dummy] = 'dummy'

          expect(AWS::CloudFormation).to receive(:new)
            .with(access_key_id: '1234567890abcdef', secret_access_key: 'abcdef1234567890')

          @adapter.create_stack 'stack_name', '{}', {}, @options
        end

        it 'set region for aws-sdk' do
          @options[:entry_point] = 'ap-northeast-1'
          expect(AWS::CloudFormation).to receive(:new).with(hash_including(region: 'ap-northeast-1'))

          @adapter.create_stack 'stack_name', '{}', {}, @options
        end

        it 'call CloudFormation#create to create stack on aws' do
          allow(AWS::CloudFormation).to receive_message_chain(:new, :stacks) do
            double('stacks').tap do |stacks|
              expect(stacks).to receive(:create).with('stack-name', '{}', hash_including(parameters: {}))
            end
          end

          @adapter.create_stack 'stack_name', '{}', {}, @options
        end
      end

      describe '#get_stack_status' do
        before do
          @stack = double('stack', status: '')
          @stacks = double('stacks', :[] => @stack)
          allow(AWS::CloudFormation).to receive_message_chain(:new, :stacks).and_return(@stacks)

          @options = {}
          @options[:key] = '1234567890abcdef'
          @options[:secret] = 'abcdef1234567890'
        end

        it 'execute without exception' do
          @adapter.get_stack_status 'stack_name', @options
        end

        it 'set credentials for aws-sdk' do
          @options[:dummy] = 'dummy'

          expect(AWS::CloudFormation).to receive(:new)
            .with(access_key_id: '1234567890abcdef', secret_access_key: 'abcdef1234567890')

          @adapter.get_stack_status 'stack_name', @options
        end

        it 'return stack status via aws-sdk' do
          expect(@stack).to receive(:status).and_return('dummy_status')
          expect(@stacks).to receive(:[]).with('stack-name').and_return(@stack)

          status = @adapter.get_stack_status 'stack_name', @options
          expect(status).to eq(:dummy_status)
        end

        it 'raise error  when target stack does not exist' do
          allow(@stacks).to receive(:[]).and_return nil
          expect { @adapter.get_stack_status 'undefined_stack', @options }.to raise_error
        end
      end

      describe '#get_outputs' do
        before do
          @outputs = []
          allow(AWS::CloudFormation).to receive_message_chain(:new, :stacks, :[], :outputs).and_return(@outputs)

          @options = {}
          @options[:key] = '1234567890abcdef'
          @options[:secret] = 'abcdef1234567890'
        end

        it 'execute without exception' do
          @adapter.get_outputs 'stack_name', @options
        end

        it 'set credentials for aws-sdk' do
          @options[:dummy] = 'dummy'

          expect(AWS::CloudFormation).to receive(:new)
            .with(access_key_id: '1234567890abcdef', secret_access_key: 'abcdef1234567890')

          @adapter.get_outputs 'stack_name', @options
        end

        it 'returns outputs hash that is converted from Array<StackOutput>' do
          stack = double(:stack)
          @outputs << AWS::CloudFormation::StackOutput.new(stack, 'key1', 'value1', 'description1')
          @outputs << AWS::CloudFormation::StackOutput.new(stack, 'key2', 'value2', 'description2')

          results = @adapter.get_outputs 'stack_name', @options
          expect(results).to eq('key1' => 'value1', 'key2' => 'value2')
        end
      end

      describe '#get_availability_zones' do
        before do
          @availability_zones = [double('availability_zone', name: 'ap-southeast-2a'), double('availability_zone', name: 'ap-southeast-2b')]
          allow(AWS::EC2).to receive_message_chain(:new, :availability_zones).and_return(@availability_zones)

          @options = {}
          @options[:key] = '1234567890abcdef'
          @options[:secret] = 'abcdef1234567890'
        end

        it 'execute without exception' do
          @adapter.get_availability_zones @options
        end

        it 'set credentials for aws-sdk' do
          @options[:dummy] = 'dummy'

          expect(AWS::EC2).to receive(:new)
            .with(access_key_id: '1234567890abcdef', secret_access_key: 'abcdef1234567890')

          @adapter.get_availability_zones @options
        end

        it 'return AvailabilityZone names' do
          availability_zones = @adapter.get_availability_zones @options
          expect(availability_zones).to eq(['ap-southeast-2a', 'ap-southeast-2b'])
        end

        it 'raise error  when target AvailabilityZones does not exist' do
          allow(@availability_zones).to receive(:map).and_return nil
          expect { @adapter.adapter.get_availability_zones @options }.to raise_error
        end
      end

      describe '#destroy_stack' do
        before do
          allow(AWS::CloudFormation).to receive_message_chain(:new, :stacks, :[], :delete)

          @options = {}
          @options[:key] = '1234567890abcdef'
          @options[:secret] = 'abcdef1234567890'
        end

        it 'execute without exception' do
          @adapter.destroy_stack 'stack_name', {}
        end

        it 'set credentials for aws-sdk' do
          @options[:dummy] = 'dummy'

          expect(AWS::CloudFormation).to receive(:new)
            .with(access_key_id: '1234567890abcdef', secret_access_key: 'abcdef1234567890')

          @adapter.destroy_stack 'stack_name', @options
        end

        it 'set region for aws-sdk' do
          @options[:entry_point] = 'ap-northeast-1'
          expect(AWS::CloudFormation).to receive(:new).with(hash_including(region: 'ap-northeast-1'))

          @adapter.destroy_stack 'stack_name', @options
        end

        it 'call CloudFormation::Stack#delete to delete created stack on aws' do
          allow(AWS::CloudFormation).to receive_message_chain(:new, :stacks, :[]) do
            double('stack').tap do |stack|
              expect(stack).to receive(:delete)
            end
          end

          @adapter.destroy_stack 'stack_name', @options
        end
      end

      describe '#aws_options' do
        it 'return converted options for aws' do
          options = {
            key: 'dummy_key',
            secret: 'dummy_secret',
            entry_point: 'ap-northeast-1'
          }
          expected_options = {
            access_key_id: 'dummy_key',
            secret_access_key: 'dummy_secret',
            region: 'ap-northeast-1'
          }

          expect(@adapter.send(:aws_options, options)).to eq(expected_options)
        end
      end

      describe '#cloud_formation' do
        before do
          @options = {
            key: 'dummy_key',
            secret: 'dummy_secret',
            entry_point: 'ap-northeast-1'
          }
        end

        it 'set credentials for aws-sdk' do
          expect(AWS::CloudFormation).to receive(:new)
            .with(hash_including(access_key_id: 'dummy_key', secret_access_key: 'dummy_secret'))

          @adapter.send(:cloud_formation, @options)
        end

        it 'set region for aws-sdk' do
          expect(AWS::CloudFormation).to receive(:new).with(hash_including(region: 'ap-northeast-1'))

          @adapter.send(:cloud_formation, @options)
        end

        it 'return AWS::CloudFormation variable' do
          expect(@adapter.send(:cloud_formation, @options)).to be_a_kind_of(AWS::CloudFormation)
        end
      end

      describe '#ec2' do
        before do
          @options = {
            key: 'dummy_key',
            secret: 'dummy_secret',
            entry_point: 'ap-northeast-1'
          }
        end

        it 'set credentials for aws-sdk' do
          expect(AWS::EC2).to receive(:new)
            .with(hash_including(access_key_id: 'dummy_key', secret_access_key: 'dummy_secret'))

          @adapter.send(:ec2, @options)
        end

        it 'set region for aws-sdk' do
          expect(AWS::EC2).to receive(:new).with(hash_including(region: 'ap-northeast-1'))

          @adapter.send(:ec2, @options)
        end

        it 'return AWS::EC2 variable' do
          expect(@adapter.send(:ec2, @options)).to be_a_kind_of(AWS::EC2)
        end
      end

      describe '#convert_name' do
        it 'replace from underscore to hyphen to follow AWS constraint' do
          expect(@adapter.send(:convert_name, 'dummy_name-test')).to eq('dummy-name-test')
        end
      end

      describe '#convert_parameters' do
        it 'convert non-String to String' do
          parameters = { dummy: 1, sample: 'value' }
          expect(@adapter.send(:convert_parameters, parameters)).to eq(dummy: '1', sample: 'value')
        end
      end
    end
  end
end
