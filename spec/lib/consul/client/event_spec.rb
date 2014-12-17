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

        @client = Consul::Client::Event.new host: 'localhost'
      end

      describe '#fire' do
        it 'return nil if failed to request' do
          @stubs.put('/v1/event/error') { [400, {}, ''] }
          expect(@client.fire(:error)).to be_nil
        end

        it 'return hash that contains ID and name' do
          body = %({"ID":"12345678-1234-1234-1234-1234567890ab","Name":"configure","Payload":null,"NodeFilter":"","ServiceFilter":"","TagFilter":"","Version":1,"LTime":0})
          @stubs.put('/v1/event/configure') { [200, {}, body] }

          result = @client.fire(:configure)
          expect(result).to be_is_a Hash
          expect(result.keys).to match_array %w(ID Name Payload NodeFilter ServiceFilter TagFilter Version LTime)
          expect(result[:ID]).to match(/^[a-f0-9\-]{36}$/)
          expect(result[:Name]).to eq('configure')
        end
      end

      describe '#get' do
        it 'return nil if target event does not exist' do
          @stubs.get('/v1/kv/event/12345678-1234-1234-1234-1234567890ab?recurse=') { [404, {}, ''] }
          expect(@client.get('12345678-1234-1234-1234-1234567890ab')).to be_nil
        end

        it 'return EventResults that is created from responsed json' do
          body = <<-EOS
            [
              {
                "CreateIndex":88,
                "ModifyIndex":91,
                "LockIndex":0,
                "Key":"event/12345678-1234-1234-1234-1234567890ab/host1",
                "Flags":0,
                "Value":"eyJldmVudF9pZCI6IjRlZTVkMmE2LTg1M2EtMjFhOS03NDYzLWVmMTg2NjQ2OGI3NiIsInR5cGUiOiJjb25maWd1cmUiLCJyZXN1bHQiOiIwIiwic3RhcnRfZGF0ZXRpbWUiOiIyMDE0LTEyLTE2VDE0OjQ0OjA3KzA5MDAiLCJlbmRfZGF0ZXRpbWUiOiIyMDE0LTEyLTE2VDE0OjQ0OjA5KzA5MDAifQ=="
              },
              {
                "CreateIndex":89,
                "ModifyIndex":90,
                "LockIndex":0,
                "Key":"event/12345678-1234-1234-1234-1234567890ab/host2",
                "Flags":0,
                "Value":"eyJldmVudF9pZCI6IjRlZTVkMmE2LTg1M2EtMjFhOS03NDYzLWVmMTg2NjQ2OGI3NiIsInR5cGUiOiJjb25maWd1cmUiLCJyZXN1bHQiOiIwIiwic3RhcnRfZGF0ZXRpbWUiOiIyMDE0LTEyLTE2VDE0OjQ0OjA3KzA5MDAiLCJlbmRfZGF0ZXRpbWUiOiIyMDE0LTEyLTE2VDE0OjQ0OjA4KzA5MDAifQ=="
              }
            ]
          EOS

          @stubs.get('/v1/kv/event/12345678-1234-1234-1234-1234567890ab?recurse=') { [200, {}, body] }

          expect(EventResults).to receive(:parse).with(body).and_return(EventResults.new('[]'))
          expect(@client.get('12345678-1234-1234-1234-1234567890ab')).to be_is_a(EventResults)
        end
      end
    end
  end
end
