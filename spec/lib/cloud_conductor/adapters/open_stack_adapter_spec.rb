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
          ::Fog::Orchestration.stub_chain(:new, :create_stack)

          @options = {}
          @options[:entry_point] = 'http://127.0.0.1:5000/'
          @options[:key] = 'test_user'
          @options[:secret] = 'test_secret'
          @options[:tenant_id] = 'test_tenant'
        end

        it 'execute without exception' do
          @adapter.create_stack 'stack_name', '{}', '{}', {}
        end

        it 'instantiate' do
          @options[:dummy] = 'dummy'

          ::Fog::Orchestration.should_receive(:new)
            .with(
              provider: :OpenStack,
              openstack_auth_url: 'http://127.0.0.1:5000/v2.0/tokens',
              openstack_api_key: 'test_secret',
              openstack_username: 'test_user',
              openstack_tenant: 'test_tenant'
            )

          @adapter.create_stack 'stack_name', '{}', '{}', @options
        end

        it 'call Fog::Orchestration#create_stack to create stack on openstack' do
          ::Fog::Orchestration.stub_chain(:new) do
            double('newfog').tap do |newfog|
              newfog.should_receive(:create_stack).with('stack_name', hash_including(template: '{}', parameters: {}))
            end
          end

          @adapter.create_stack 'stack_name', '{}', '{}', @options
        end
      end
    end
  end
end
