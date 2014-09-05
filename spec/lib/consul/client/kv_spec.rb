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
module Consul
  module Client
    describe KV do
      before do
        original_method = Faraday.method(:new)
        Faraday.stub(:new) do |*args, &block|
          @stubs  = Faraday::Adapter::Test::Stubs.new
          @test = original_method.call(*args) do |builder|
            builder.adapter :test, @stubs
            yield block if block
          end
        end

        @client = KV.new host: 'localhost'
      end

      describe '#get' do
        def add_stub(path, value)
          encoded_value = Base64.encode64(value).chomp
          body = %([{"CreateIndex":5158,"ModifyIndex":5158,"LockIndex":0,"Key":"hoge","Flags":0,"Value":"#{encoded_value}"}])
          @stubs.get(path) { [200, {}, body] }
        end

        it 'return nil if specified key does not exist' do
          @stubs.get('/v1/kv/not_found') { [404, {}, ''] }
          expect(@client.get('not_found')).to be_nil
        end

        it 'return string if consul does not return JSON format string' do
          add_stub '/v1/kv/dummy', 'dummy_value'
          expect(@client.get('dummy')).to be_is_a String
        end

        it 'request GET /v1/kv with key and return decoded response body' do
          add_stub '/v1/kv/dummy', 'dummy_value'
          expect(@client.get 'dummy').to eq('dummy_value')
        end

        it 'return hash if consul return JSON format string' do
          add_stub '/v1/kv/json', '{ "key": "value" }'
          expect(@client.get('json')).to be_is_a Hash
        end

        it 'request GET /v1/kv with key and return parsed decoded response body' do
          add_stub '/v1/kv/json', '{ "key": "value" }'
          expect(@client.get 'json').to eq('key' => 'value')
        end
      end

      describe '#put' do
        let(:should_yield) do
          (-> {}).tap { |proc| proc.should_receive(:call) }
        end

        it 'will request PUT /v1/kv with key' do
          @stubs.put('/v1/kv/dummy', &should_yield)
          @client.put 'dummy', 'dummy_value'
        end

        it 'will request PUT /v1/kv with value' do
          @stubs.put('/v1/kv/dummy') do |env|
            expect(env.body).to eq('dummy_value')
          end
          @client.put 'dummy', 'dummy_value'
        end

        it 'will request PUT /v1/kv with JSON encoded value if value is Hash' do
          @stubs.put('/v1/kv/dummy') do |env|
            expect(env.body).to eq('{"key":"value"}')
          end
          @client.put 'dummy', key: 'value'
        end
      end
    end
  end
end
