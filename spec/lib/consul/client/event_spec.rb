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
require 'consul/client/event'
module Consul
  class Client
    describe Event do
      before do
        @stubs  = Faraday::Adapter::Test::Stubs.new

        original_method = Faraday.method(:new)
        allow(Faraday).to receive(:new) do |*args, &block|
          original_method.call(*args) do |builder|
            builder.adapter :test, @stubs
            yield block if block
          end
        end

        @faraday = Faraday.new('http://localhost/v1')
        @client = Consul::Client::Event.new @faraday
      end

      describe '#fire' do
        it 'return consul event ID' do
          body = %({"ID":"12345678-1234-1234-1234-1234567890ab","Name":"configure","Payload":null,"NodeFilter":"","ServiceFilter":"","TagFilter":"","Version":1,"LTime":0})
          @stubs.put('/v1/event/fire/configure') { [200, {}, body] }

          result = @client.fire(:configure)
          expect(result).to be_is_a String
          expect(result).to match(/^[a-f0-9\-]{36}$/)
        end

        it 'send PUT request with payload' do
          @stubs.put('/v1/event/fire/dummy') do |env|
            expect(env.body).to eq('dummy_token')
          end
          @client.fire(:dummy, 'dummy_token')
        end

        it 'send PUT request with node filter' do
          @stubs.put('/v1/event/fire/dummy') do |env|
            expect(env.params['node']).to eq('node1|node2')
          end
          @client.fire(:dummy, nil, node: %w(node1 node2))
        end

        it 'send PUT request with service filter' do
          @stubs.put('/v1/event/fire/dummy') do |env|
            expect(env.params['service']).to eq('service1|service2')
          end
          @client.fire(:dummy, nil, service: %w(service1 service2))
        end

        it 'send PUT request with tag filter' do
          @stubs.put('/v1/event/fire/dummy') do |env|
            expect(env.params['tag']).to eq('tag1|tag2')
          end
          @client.fire(:dummy, nil, tag: %w(tag1 tag2))
        end
      end
    end
  end
end
