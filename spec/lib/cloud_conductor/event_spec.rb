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
  describe Event do
    before do
      @client = double(:client)
      allow(@client).to receive_message_chain(:kv, :merge)
      allow(@client).to receive_message_chain(:kv, :get)
      allow(@client).to receive_message_chain(:event, :fire)
      allow(Consul::Client).to receive(:new).and_return(@client)

      @event = CloudConductor::Event.new 'localhost', 8500, token: 'dummy_token'
    end

    describe '#initialize' do
      it 'create  Consul::Client instance' do
        expect(Consul::Client).to receive(:new)
        CloudConductor::Event.new 'localhost', 8500, token: 'dummy_token'
      end

      it 'keep token in instance variable' do
        expect(@event.instance_variable_get(:@token)).to eq('dummy_token')
      end
    end

    describe '#fire' do
      it 'call KV#merge' do
        expect(@client).to receive_message_chain(:kv, :merge).with('dummy/key1', {})
        expect(@client).to receive_message_chain(:kv, :merge).with('dummy/key2', {})
        payload = {
          'dummy/key1' => {
          },
          'dummy/key2' => {
          }
        }
        @event.fire(:configure, payload)
      end

      it 'call Event#fire with token' do
        expect(@client).to receive_message_chain(:event, :fire).with(:configure, 'dummy_token', {})
        @event.fire(:configure, {})
      end

      it 'return nil if failed to request' do
        allow(@client).to receive_message_chain(:event, :fire).and_return(nil)
        expect(@event.fire(:error)).to be_nil
      end

      it 'return consul event ID' do
        allow(@client).to receive_message_chain(:event, :fire).and_return('12345678-1234-1234-1234-1234567890ab')

        event_id = @event.fire(:configure)
        expect(event_id).to be_is_a String
        expect(event_id).to match(/^[a-f0-9\-]{36}$/)
      end
    end

    describe '#sync_fire' do
      before do
        nodes = [{ hostname: 'dummy_host', log: 'dummy_log' }]
        @event_result = double(:event_result)
        allow(@event_result).to receive(:success?).and_return(true)
        allow(@event_result).to receive(:nodes).and_return(nodes)
        allow(@event_result).to receive_message_chain(:refresh!, :to_json).and_return('{"dummy": "value"}')

        allow(@event).to receive(:fire).and_return(1)
        allow(@event).to receive(:wait).and_return('dummy_event')
        allow(@event).to receive(:find).and_return(@event_result)
      end

      it 'call fire' do
        expect(@event).to receive(:fire).with(:configure, {}, {})

        @event.sync_fire(:configure, {}, {})
      end

      it 'call wait' do
        expect(@event).to receive(:wait)

        @event.sync_fire(:configure, {})
      end

      it 'call find' do
        expect(@event).to receive(:find)

        @event.sync_fire(:configure, {})
      end

      it 'fail if wait method has timed out' do
        allow(@event).to receive(:wait).and_raise(Timeout::Error)

        expect { @event.sync_fire(:error) }.to raise_error
      end

      it 'fail if success? method returns false' do
        allow(@event_result).to receive(:success?).and_return(false)

        expect { @event.sync_fire(:error) }.to raise_error(/error event has failed.\n\s*{\s*.*\s*}/)
      end
    end

    describe '#wait' do
      it 'will return immediately if target event had finished' do
        event_result = double(:event_result, finished?: true)
        allow(@event).to receive(:find).and_return(event_result)
        expect(@event).not_to receive(:sleep)
        @event.wait('dummy_event')
      end

      it 'will wait until target event are finished' do
        unfinished_log = double(:event_result, finished?: false)
        finished_log = double(:event_result, finished?: true)
        allow(@event).to receive(:find).and_return(nil, unfinished_log, finished_log)
        expect(@event).to receive(:sleep).twice
        @event.wait('dummy_event')
      end
    end

    describe '#list' do
      it 'delegate to Metronome::EventResult' do
        expect(Metronome::EventResult).to receive(:list).with(@client)
        @event.list
      end
    end

    describe '#find' do
      it 'delegate to Metronome::EventResult' do
        event_result = double(:event_result, refresh!: nil)
        expect(Metronome::EventResult).to receive(:find).with(@client, 'dummy_id').and_return(event_result)
        @event.find('dummy_id')
      end
    end
  end
end
