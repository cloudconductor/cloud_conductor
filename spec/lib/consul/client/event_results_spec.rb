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
    describe EventResults do
      before do
        @json = <<-EOS
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
      end

      describe '.parse' do
        it 'return instance that contains parsed results' do
          results = EventResults.parse(@json)
          expect(results).to be_is_a EventResults

          inner_data = results.instance_variable_get(:@results)
          expect(inner_data).to be_is_a Hash
          expect(inner_data.size).to eq(2)
          expect(inner_data.keys).to match_array %w(host1 host2)

          expect(inner_data['host1']).to be_is_a Hash
          expect(inner_data['host1'].keys).to match_array %i(event_id type result start_datetime end_datetime)
          expect(inner_data['host1']).to eq(
            event_id: '4ee5d2a6-853a-21a9-7463-ef1866468b76',
            type: 'configure',
            result: 0,
            start_datetime: DateTime.new(2014, 12, 16, 14, 44, 7, 'JST'),
            end_datetime: DateTime.new(2014, 12, 16, 14, 44, 9, 'JST')
          )
        end
      end

      describe '#size' do
        it 'return size of results' do
          results = EventResults.parse(@json)
          expect(results.size).to eq(2)
        end
      end

      describe '#[]' do
        it 'return result of target host' do
          results = EventResults.parse(@json)
          expect(results['host1']).to be_is_a Hash
          expect(results['host1'].keys).to match_array %i(event_id type result start_datetime end_datetime)
        end
      end

      describe 'finished?' do
        it 'return true if event on all hosts are finished' do
          results = EventResults.parse(@json)
          expect(results.finished?).to be_truthy
        end

        it 'return false if any event has not been finished' do
          results = EventResults.parse(@json)
          inner_data = results.instance_variable_get(:@results)
          inner_data['host1'][:result] = nil

          expect(results.finished?).to be_falsey
        end
      end

      describe 'success?' do
        it 'return true if event on all hosts are succeeded' do
          results = EventResults.parse(@json)
          expect(results.success?).to be_truthy
        end

        it 'return false if any event has not been finished' do
          results = EventResults.parse(@json)
          inner_data = results.instance_variable_get(:@results)
          inner_data['host1'][:result] = nil

          expect(results.success?).to be_falsey
        end

        it 'return false if any event has occurred error' do
          results = EventResults.parse(@json)
          inner_data = results.instance_variable_get(:@results)
          inner_data['host2'][:result] = 1

          expect(results.success?).to be_falsey
        end
      end
    end
  end
end
