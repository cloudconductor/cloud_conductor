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
module Serf
  describe Client do
    describe '#initialize' do
      it 'initialized client without error when specified host option' do
        Client.new host: 'localhost'
      end

      it 'raise error when host does not specified' do
        expect { Client.new }.to raise_error 'Serf::Client require host option'
      end
    end

    describe '#call' do
      before do
        options = { format: 'text' }
        @client = Client.new host: 'localhost', options: options
        @client.stub(:systemu).and_return([double('status', 'success?' => true), '{}'])

        @kv_stub = double('KV', merge: nil)
        Consul::Client.stub_chain(:connect, :kv).and_return @kv_stub
      end

      it 'will execute serf with specified options' do
        @client.should_receive(:systemu).with(include('-format=text'))
        @client.call('info')
      end

      it 'will execute serf with specified main command' do
        @client.should_receive(:systemu).with(include('info'))
        @client.call('info')
      end

      it 'will execute serf with specified sub command' do
        @client.should_receive(:systemu).with(include('dummy'))
        @client.call('info', 'dummy')
      end

      it 'will call Consul::Client::KV#merge with specified payload' do
        payload = { key: 'value' }
        @kv_stub.should_receive(:merge).with('cloudconductor/parameters', payload)
        @client.call('info', nil, payload)
      end
    end
  end
end
