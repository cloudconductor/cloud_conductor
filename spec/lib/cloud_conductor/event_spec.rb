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
        expect(@client).to receive_message_chain(:kv, :merge).with(CloudConductor::Event::PAYLOAD_KEY, {})
        @event.fire(:configure, {})
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
        nodes = [{ hostname: 'dummy_host', log_message: 'dummy_log' }]
        @event_log = double(:event_log)
        allow(@event_log).to receive(:success?).and_return(true)
        allow(@event_log).to receive(:nodes).and_return(nodes)

        allow(@event).to receive(:fire).and_return(1)
        allow(@event).to receive(:wait).and_return('dummy_event')
        allow(@event).to receive(:find).and_return(@event_log)
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
        allow(@event_log).to receive(:success?).and_return(false)

        expect { @event.sync_fire(:error) }.to raise_error("error event has failed.\n{\"dummy_host\":\"dummy_log\"}")
      end
    end

    describe '#wait' do
      it 'will return immediately if target event had finished' do
        event_log = double(:event_log, finished?: true)
        allow(@event).to receive(:find).and_return(event_log)
        expect(@event).not_to receive(:sleep)
        @event.wait('dummy_event')
      end

      it 'will wait until target event are finished' do
        unfinished_log = double(:event_log, finished?: false)
        finished_log = double(:event_log, finished?: true)
        allow(@event).to receive(:find).and_return(nil, unfinished_log, finished_log)
        expect(@event).to receive(:sleep).twice
        @event.wait('dummy_event')
      end
    end

    describe '#find' do
      it 'return nil if target event does not exist or request failed' do
        allow(@client).to receive_message_chain(:kv, :get).and_return(nil)
        expect(@event.find('12345678-1234-1234-1234-1234567890ab')).to be_nil
      end

      it 'return EventLog that is created from responsed json' do
        value = {
          'event/12345678-1234-1234-1234-1234567890ab/host1' => {
            'event_id' => '4ee5d2a6-853a-21a9-7463-ef1866468b76',
            'type' => 'configure',
            'result' => '0',
            'start_datetime' => '2014-12-16T14:44:07+0900',
            'end_datetime' => '2014-12-16T14:44:09+0900',
            'log' => 'Dummy consul event log1'
          },
          'event/12345678-1234-1234-1234-1234567890ab/host2' => {
            'event_id' => '4ee5d2a6-853a-21a9-7463-ef1866468b76',
            'type' => 'configure',
            'result' => '0',
            'start_datetime' => '2014-12-16T14:44:07+0900',
            'end_datetime' => '2014-12-16T14:44:09+0900',
            'log' => 'Dummy consul event log2'
          }
        }

        allow(@client).to receive_message_chain(:kv, :get).and_return(value)

        expect(EventLog).to receive(:new).with(value).and_return(EventLog.new(value))
        expect(@event.find('12345678-1234-1234-1234-1234567890ab')).to be_is_a(EventLog)
      end
    end
  end
end
