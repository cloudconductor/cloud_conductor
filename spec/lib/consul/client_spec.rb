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
      @stubs = Faraday::Adapter::Test::Stubs.new

      original_method = Faraday.method(:new)
      allow(Faraday).to receive(:new) do |*args, &block|
        original_method.call(*args) do |builder|
          builder.adapter :test, @stubs
          yield block if block
        end
      end

      @client = Consul::Client.new 'localhost'
    end

    describe '#initialize' do
      it 'raise error when host does not specified' do
        expect { Consul::Client.new(nil) }.to raise_error 'Consul::Client require host option'
      end

      it 'does not occurred any error when specified valid options' do
        Consul::Client.new 'localhost'
      end

      it 'create faraday client for host when passed argument as string' do
        client = Consul::Client.new 'localhost'
        expect(client.instance_variable_get(:@faradaies).map(&:host)).to eq(%w(localhost))
      end

      it 'create faraday client for host when passed argument as array' do
        client = Consul::Client.new ['localhost']
        expect(client.instance_variable_get(:@faradaies).map(&:host)).to eq(%w(localhost))
      end

      it 'create faraday client for each address when host has multiple addresses as string' do
        client = Consul::Client.new 'localhost, 192.168.0.1'
        expect(client.instance_variable_get(:@faradaies).map(&:host)).to eq(%w(localhost 192.168.0.1))
      end

      it 'create faraday client for each address when host has multiple addresses' do
        client = Consul::Client.new ['localhost', '192.168.0.1']
        expect(client.instance_variable_get(:@faradaies).map(&:host)).to eq(%w(localhost 192.168.0.1))
      end
    end

    describe '#kv' do
      it 'return KV instance' do
        expect(@client.kv).to be_is_a Consul::Client::KV
      end
    end

    describe '#event' do
      it 'return Event instance' do
        expect(@client.event).to be_is_a Consul::Client::Event
      end
    end

    describe '#catalog' do
      it 'return Catalog instance' do
        expect(@client.catalog).to be_is_a Consul::Client::Catalog
      end
    end

    describe '#running?' do
      let(:should_yield) do
        (-> {}).tap { |proc| expect(proc).to receive(:call) }
      end

      it 'will request http://host:8500/v1/status/leader' do
        @stubs.get('/v1/status/leader', &should_yield)
        @client.running?
      end

      it 'return true when API return 200 status code and leader address' do
        @stubs.get('/v1/status/leader') { [200, {}, '"127.0.0.1:8300"'] }
        expect(@client.running?).to be_truthy
      end

      it 'return false when API return 500 status code' do
        @stubs.get('/v1/status/leader') { [500, {}, ''] }
        expect(@client.running?).to be_falsey
      end

      it 'return false before leader elect in consul cluster' do
        @stubs.get('/v1/status/leader') { [200, {}, '""'] }
        expect(@client.running?).to be_falsey
      end

      it 'return false when some error occurred while request' do
        @stubs.get('/v1/status/leader') { fail Faraday::ConnectionFailed, '' }
        expect(@client.running?).to be_falsey
      end
    end
  end
end
