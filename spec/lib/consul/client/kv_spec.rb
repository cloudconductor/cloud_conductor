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
  class Client
    describe KV do
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
        @client = KV.new @faraday, token: 'dummy_token'
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

        it 'return hash if recursive response' do
          encoded_value1 = Base64.encode64('value1').chomp
          encoded_value2 = Base64.encode64('value2').chomp
          body = %([
            {"CreateIndex":5158,"ModifyIndex":5158,"LockIndex":0,"Key":"json/1","Flags":0,"Value":"#{encoded_value1}"},
            {"CreateIndex":5159,"ModifyIndex":5159,"LockIndex":0,"Key":"json/2","Flags":0,"Value":"#{encoded_value2}"}
          ])
          @stubs.get('/v1/kv/json') { [200, {}, body] }

          result = @client.get('json', true)
          expect(result).to be_is_a Hash
          expect(result).to eq('json/1' => 'value1', 'json/2' => 'value2')
        end

        it 'return hash that contains hashes if recursive response has json string' do
          encoded_value1 = Base64.encode64('{ "dummy": "value" }').chomp
          encoded_value2 = Base64.encode64('value2').chomp
          body = %([
            {"CreateIndex":5158,"ModifyIndex":5158,"LockIndex":0,"Key":"json/1","Flags":0,"Value":"#{encoded_value1}"},
            {"CreateIndex":5159,"ModifyIndex":5159,"LockIndex":0,"Key":"json/2","Flags":0,"Value":"#{encoded_value2}"}
          ])
          @stubs.get('/v1/kv/json') { [200, {}, body] }

          result = @client.get('json', true)
          expect(result).to be_is_a Hash
          expect(result['json/1']).to be_is_a Hash
          expect(result['json/2']).to be_is_a String
        end

        it 'request GET /v1/kv with key and return parsed decoded response body' do
          add_stub '/v1/kv/json', '{ "key": "value" }'
          expect(@client.get 'json').to eq('key' => 'value')
        end

        it 'send GET request with token' do
          @stubs.get('/v1/kv/json') do |env|
            expect(env.url.query).to eq('token=dummy_token')
          end
          @client.get 'json'
        end

        it 'send GET request with recursive option and token' do
          @stubs.get('/v1/kv/json') do |env|
            expect(env.url.query).to eq('recurse=&token=dummy_token')
          end
          @client.get 'json', true
        end
      end

      describe '#put' do
        let(:should_yield) do
          (-> {}).tap { |proc| expect(proc).to receive(:call) }
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

        it 'send PUT request with token' do
          @stubs.put('/v1/kv/dummy') do |env|
            expect(env.url.query).to eq('token=dummy_token')
          end
          @client.put 'dummy', key: 'value'
        end
      end

      describe '#merge' do
        before do
          allow(@client).to receive(:get)
          allow(@client).to receive(:put)
        end

        it 'will get value' do
          expect(@client).to receive(:get).with('dummy')

          @client.merge 'dummy', key: 'value'
        end

        it 'overwrite value if previous value isn\'t hash' do
          allow(@client).to receive(:get).and_return('value')
          expect(@client).to receive(:put).with('dummy', key: 'value')

          @client.merge 'dummy', key: 'value'
        end

        it 'merge both hashes if previous value is hash' do
          allow(@client).to receive(:get).and_return(key: 'previous', key2: 'previous2')
          expect(@client).to receive(:put).with('dummy', key: 'value', key2: 'previous2')

          @client.merge 'dummy', key: 'value'
        end

        it 'merge deep hashes if previous value has hierarchy hash' do
          allow(@client).to receive(:get).and_return(key: 'previous', key2: { subkey: 'previous2' })
          expect(@client).to receive(:put).with('dummy', key: 'value', key2: { subkey: 'previous2', subkey2: 'value' })

          @client.merge 'dummy', key: 'value', key2: { subkey2: 'value' }
        end
      end

      describe '#safety_parse' do
        it 'return Hash if arguments has json string' do
          value = '{ "key": "value" }'
          result = @client.send(:safety_parse, value)
          expect(result).to be_is_a(Hash)
          expect(result).to eq('key' => 'value')
        end

        it 'return String if arguments has not json string' do
          value = 'dummy string'
          result = @client.send(:safety_parse, value)
          expect(result).to be_is_a(String)
          expect(result).to eq('dummy string')
        end
      end
    end
  end
end
