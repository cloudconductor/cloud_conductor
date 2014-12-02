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
  module Adapters
    describe DummyAdapter do
      before do
        @adapter = DummyAdapter.new
        allow(Log).to receive(:debug)
      end

      it 'extend AbstractAdapter class' do
        expect(DummyAdapter.superclass).to eq(AbstractAdapter)
      end

      it 'has :dummy type' do
        expect(DummyAdapter::TYPE).to eq(:dummy)
      end

      describe '#create_stack' do
        before do
          @options = {}
          @options[:key] = '1234567890abcdef'
          @options[:secret] = 'abcdef1234567890'
        end

        it 'execute without exception' do
          @adapter.create_stack 'stack_name', '{}', {}, {}
        end

        it 'output log' do
          expect(Log).to receive(:debug).with('Starting method CloudConductor::Adapters::DummyAdapter.create_stack')
          @adapter.create_stack 'stack_name', '{}', {}, {}
        end
      end

      describe '#get_stack_status' do
        it 'execute without exception' do
          @adapter.get_stack_status 'stack_name', {}
        end

        it 'output log' do
          expect(Log).to receive(:debug).with('Starting method CloudConductor::Adapters::DummyAdapter.get_stack_status')
          @adapter.get_stack_status 'stack_name', {}
        end
      end

      describe '#destroy_stack' do
        it 'execute without exception' do
          @adapter.destroy_stack 'stack_name', {}
        end

        it 'output log' do
          expect(Log).to receive(:debug).with('Starting method CloudConductor::Adapters::DummyAdapter.destroy_stack')
          @adapter.destroy_stack 'stack_name', {}
        end
      end
    end
  end
end
