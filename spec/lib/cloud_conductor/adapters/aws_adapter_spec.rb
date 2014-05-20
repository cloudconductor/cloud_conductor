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
          AWS::CloudFormation.stub_chain(:new, :stacks, :create)

          @options = {}
          @options[:key] = '1234567890abcdef'
          @options[:secret] = 'abcdef1234567890'
        end

        it 'execute without exception' do
          @adapter.create_stack 'stack_name', '{}', '{}', {}
        end

        it 'set credentials for aws-sdk' do
          @options[:dummy] = 'dummy'

          AWS::CloudFormation.should_receive(:new)
            .with(access_key_id: '1234567890abcdef', secret_access_key: 'abcdef1234567890')

          @adapter.create_stack 'stack_name', '{}', '{}', @options
        end

        it 'call CloudFormation#create to create stack on aws' do
          AWS::CloudFormation.stub_chain(:new, :stacks) do
            double('stacks').tap do |stacks|
              stacks.should_receive(:create).with('stack_name', '{}', hash_including(parameters: {}))
            end
          end

          @adapter.create_stack 'stack_name', '{}', '{}', @options
        end
      end
    end
  end
end
