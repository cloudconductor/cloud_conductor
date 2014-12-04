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
require 'consul/client'
module Consul
  describe Client do
    before do
      @stubs  = Faraday::Adapter::Test::Stubs.new

      original_method = Faraday.method(:new)
      allow(Faraday).to receive(:new) do |*args, &block|
        original_method.call(*args) do |builder|
          builder.adapter :test, @stubs
          yield block if block
        end
      end
    end

    describe '.connect' do
      it 'will return instance of Consul::Client::Client' do
        result = Consul::Client.connect(host: 'localhost')
        expect(result).to be_is_a Consul::Client::Client
      end
    end

    describe Client do
      before do
        @client = Consul::Client::Client.new host: 'localhost'
      end

      describe '#initialize' do
        it 'raise error when host does not specified' do
          expect { Consul::Client::Client.new }.to raise_error 'Consul::Client require host option'
        end

        it 'does not occurred any error when specified valid options' do
          options = { host: 'localhost' }
          Consul::Client::Client.new options
        end
      end

      describe '#kv' do
        it 'return KV instance' do
          expect(@client.kv).to be_is_a Consul::Client::KV
        end
      end

      describe '#running?' do
        let(:should_yield) do
          (-> {}).tap { |proc| expect(proc).to receive(:call) }
        end

        it 'will request http://host:8500/ ' do
          @stubs.get('/', &should_yield)
          @client.running?
        end

        it 'return true when API return 200 status code' do
          @stubs.get('/') { [200, {}, 'Consul Agent'] }
          expect(@client.running?).to be_truthy
        end

        it 'return false when API return 500 status code' do
          @stubs.get('/') { [500, {}, ''] }
          expect(@client.running?).to be_falsey
        end

        it 'return false when some error occurred while request' do
          @stubs.get('/') { fail Faraday::ConnectionFailed, '' }
          expect(@client.running?).to be_falsey
        end
      end
    end
  end
end
