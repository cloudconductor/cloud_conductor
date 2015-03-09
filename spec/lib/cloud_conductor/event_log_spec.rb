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
  describe EventLog do
    before do
      response = {
        'event/4ee5d2a6-853a-21a9-7463-ef1866468b76/host1' => {
          'event_id' => '4ee5d2a6-853a-21a9-7463-ef1866468b76',
          'type' => 'configure',
          'return_code' => '0',
          'started_at' => '2014-12-16T14:44:07+0900',
          'finished_at' => '2014-12-16T14:44:09+0900',
          'log' => 'Dummy consul event log'
        },
        'event/4ee5d2a6-853a-21a9-7463-ef1866468b76/host2' => {
          'event_id' => '4ee5d2a6-853a-21a9-7463-ef1866468b76',
          'type' => 'configure',
          'return_code' => '0',
          'started_at' => '2014-12-16T14:44:07+0900',
          'finished_at' => '2014-12-16T14:44:09+0900',
          'log' => 'Dummy consul event log'
        }
      }

      @event_log = EventLog.new(response)
    end

    describe '#id' do
      it 'return event id that is contained result' do
        expect(@event_log.id).to eq('4ee5d2a6-853a-21a9-7463-ef1866468b76')
      end
    end

    describe '#name' do
      it 'return event name that is contained result' do
        expect(@event_log.name).to eq('configure')
      end
    end

    describe '#nodes' do
      it 'return nodes that contain result of each host' do
        nodes = @event_log.nodes
        expect(nodes).to be_is_a(Array)
        expect(nodes.size).to eq(2)
        expect(nodes.first).to eq(
          hostname: 'host1',
          return_code: 0,
          started_at: DateTime.new(2014, 12, 16, 14, 44, 7, 'JST'),
          finished_at: DateTime.new(2014, 12, 16, 14, 44, 9, 'JST'),
          log: 'Dummy consul event log'
        )
      end
    end

    describe 'finished?' do
      it 'return true if event on all hosts are finished' do
        expect(@event_log.finished?).to be_truthy
      end

      it 'return false if any event has not been finished' do
        @event_log.nodes.first[:return_code] = nil

        expect(@event_log.finished?).to be_falsey
      end
    end

    describe 'success?' do
      it 'return true if event on all hosts are succeeded' do
        expect(@event_log.success?).to be_truthy
      end

      it 'return false if any event has not been finished' do
        @event_log.nodes.first[:return_code] = nil

        expect(@event_log.success?).to be_falsey
      end

      it 'return false if any event has occurred error' do
        @event_log.nodes.first[:return_code] = 1

        expect(@event_log.success?).to be_falsey
      end
    end
  end
end
