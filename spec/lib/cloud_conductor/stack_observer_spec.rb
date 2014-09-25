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
  describe StackObserver do
    before do
      @stack = FactoryGirl.create(:stack)

      CloudConductor::Client.stub_chain(:new, :create_stack)
      @stack.save!

      @system = @stack.system

      Stack.any_instance.stub(:status).and_return(:CREATE_COMPLETE)
      Stack.any_instance.stub(:outputs).and_return('FrontendAddress' => '127.0.0.1')
      Serf::Client.any_instance.stub(:call).and_return(double('status', 'success?' => true))
      Consul::Client::Client.any_instance.stub(:running?).and_return(true)

      @serf_client = double(:serf_client)
      @serf_client.stub(:call).with(any_args)
      @system.stub(:serf).and_return(@serf_client)
    end

    describe '#update' do
      before do
        @observer = StackObserver.new
        @observer.stub(:update_stack)
      end

      it 'check all stacks without exception' do
        @observer.update
      end

      it 'will check stack status' do
        mock = double('status')
        mock.should_receive(:dummy).at_least(1)
        Stack.any_instance.stub(:status) do
          mock.dummy
        end
        @observer.update
      end

      it 'will retrieve stack outputs' do
        mock = double('outputs')
        mock.should_receive(:dummy).at_least(1)
        Stack.any_instance.stub(:outputs) do
          mock.dummy
          { 'FrontendAddress' => '127.0.0.1' }
        end
        @observer.update
      end

      it 'will call serf request to check serf availability' do
        mock = double('client')
        mock.should_receive(:dummy).at_least(1)
        Serf::Client.any_instance.stub(:call) do
          mock.dummy
          double('status', 'success?' => true)
        end
        @observer.update
      end

      it 'will call consul request to check consul availability' do
        mock = double('client')
        mock.should_receive(:dummy).at_least(1)
        Consul::Client::Client.any_instance.stub(:running?) do
          mock.dummy
          true
        end
        @observer.update
      end

      it 'will call update_stack' do
        @observer.should_receive(:update_stack).with(@stack, '127.0.0.1')
        @observer.update
      end
    end

    describe '#update_stack' do
      before do
        System.skip_callback :save, :before, :enable_monitoring
        System.skip_callback :save, :before, :update_dns

        @observer = StackObserver.new
        @observer.stub(:sleep)

        @system.stub(:deploy_applications)
      end

      after do
        System.set_callback :save, :before, :enable_monitoring, if: -> { monitoring_host_changed? }
        System.set_callback :save, :before, :update_dns, if: -> { ip_address }
      end

      it 'will request configure event to serf with payload' do
        expected_payload = { 'dummy' => 'value' }
        @serf_client.should_receive(:call).with('event', 'configure', expected_payload)

        @observer.send(:update_stack, @stack, '127.0.0.1')
      end

      it 'will call System#deploy_applications' do
        @system.should_receive(:deploy_applications)
        @observer.send(:update_stack, @stack, '127.0.0.1')
      end

      it 'will request restore event to serf' do
        @serf_client.should_receive(:call).with('event', 'restore', {})

        @observer.send(:update_stack, @stack, '127.0.0.1')
      end
    end
  end
end
