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
      it 'update options with specified option when initialized with some options' do
        client = Client.new format: 'text'
        client.should_receive(:systemu).with(include('-format=text')).and_return([double('status', 'success?' => true), '{}'])
        client.call('info')
      end
    end

    describe '#call' do
      before do
        @client = Client.new
        @client.stub(:systemu).and_return([double('status', 'success?' => true), '{}'])
      end

      it 'will execute serf with specified command' do
        @client.should_receive(:systemu).with(include('info'))
        @client.call('info')
      end

      it 'will execute serf with specified argument as String' do
        @client.should_receive(:systemu).with(include('dummy'))
        @client.call('info', 'dummy')
      end

      it 'will execute serf with specified argument as Hash' do
        @client.should_receive(:systemu).with(include(%q('{"key":"value"}')))
        @client.call('info', key: 'value')
      end
    end
  end
end
