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
      @observer = StackObserver.new
    end

    describe '#update' do
      before do
        Stack.stub(:in_progress).and_return [@stack]
        @stack.stub(:status).and_return(:CREATE_COMPLETE)
        @stack.stub(:outputs).and_return('FrontendAddress' => '127.0.0.1')

        Consul::Client.stub_chain(:connect, :running?).and_return true
        Serf::Client.stub_chain(:new, :call, :success?).and_return true

        @observer.stub(:update_system)
      end

      it 'check all stacks without exception' do
        @observer.update
      end

      it 'will check stack status' do
        @stack.should_receive(:status)
        @observer.update
      end

      it 'update status of stack to :CREATE_COMPLETE' do
        @observer.update
        expect(@stack.status).to eq(:CREATE_COMPLETE)
      end

      context 'has platform pattern' do
        it 'will retrieve stack outputs' do
          @stack.should_receive(:outputs)
          @observer.update
        end

        it 'will call consul request to check consul availability' do
          consul_client = double('Consul::Client')
          consul_client.should_receive(:running?)

          Consul::Client.should_receive(:connect).with(host: '127.0.0.1').and_return(consul_client)

          @observer.update
        end

        it 'will call serf request to check serf availability' do
          serf_client = double('Serf::Client')
          Serf::Client.should_receive(:new).with(host: '127.0.0.1').and_return(serf_client)

          serf_client.should_receive(:call).and_return(double('Status', success?: true))
          @observer.update
        end

        it 'will call update_system' do
          @observer.should_receive(:update_system).with(@stack.system, 'FrontendAddress' => '127.0.0.1')
          @observer.update
        end
      end

      context 'has optional pattern' do
        before do
          @stack.pattern.type = :optional
        end

        it 'doesn\'t call platform check logics' do
          @stack.should_not_receive(:outputs)
          Consul::Client.should_not_receive(:connect)
          Serf::Client.should_not_receive(:new)
        end

        it 'will call update_system without outputs' do
          @observer.should_receive(:update_system).with(@stack.system, nil)
          @observer.update
        end
      end
    end

    describe '#update_system' do
      before do
        @observer.stub(:finish_system)
        @system = @stack.system
        System.skip_callback :save, :before, :enable_monitoring
        System.skip_callback :save, :before, :update_dns
        Stack.skip_callback :save, :before, :create_stack
      end

      after do
        System.set_callback :save, :before, :enable_monitoring, if: -> { monitoring_host_changed? }
        System.set_callback :save, :before, :update_dns, if: -> { ip_address }
        Stack.set_callback :save, :before, :create_stack, if: -> { status == :READY }
      end

      it 'update system when outputs exists' do
        outputs = {
          'FrontendAddress' => '127.0.0.1',
          'dummy' => 'value'
        }

        @observer.send(:update_system, @system, outputs)

        expect(@system.ip_address).to eq('127.0.0.1')
        expect(@system.monitoring_host).to eq('example.com')
        expect(@system.template_parameters).to eq('{"dummy":"value"}')
      end

      it 'change next stack status to ready' do
        @stack.status = :PENDING
        @stack.save!

        @observer.send(:update_system, @system, nil)

        expect(@system.stacks.first.status).to eq(:READY)
      end

      it 'doesn\'t call #finish_system when some stacks are pending' do
        @stack.status = :PENDING
        @stack.save!

        @observer.should_not_receive(:finish_system)
        @observer.send(:update_system, @system, nil)
      end

      it 'call #finish_system when all stacks are created' do
        @stack.status = :CREATE_COMPLETE
        @stack.save!

        @observer.should_receive(:finish_system)
        @observer.send(:update_system, @system, nil)
      end
    end

    describe '#finish_system' do
      before do
        @stack.status = :CREATE_COMPLETE
        @stack.save!

        @serf_client = double(:serf_client, call: double('status', success?: true))
        @system = @stack.system
        @system.stub(:serf).and_return(@serf_client)
        @system.stub(:send_application_payload)
        @system.stub(:deploy_applications)
        @observer.stub(:sleep)
      end

      it 'will request configure event to serf with payload' do
        expected_payload = satisfy do |payload|
          expect(payload[:cloudconductor][:patterns].keys).to eq([@stack.pattern.name])

          pattern_payload = payload[:cloudconductor][:patterns][@stack.pattern.name]
          expect(pattern_payload[:name]).to eq(@stack.pattern.name)
          expect(pattern_payload[:type]).to eq(@stack.pattern.type.to_s)
          expect(pattern_payload[:protocol]).to eq(@stack.pattern.protocol.to_s)
          expect(pattern_payload[:url]).to eq(@stack.pattern.url)
          expect(pattern_payload[:user_attributes]).to eq(JSON.parse(@stack.parameters, symbolize_names: true))
        end

        @serf_client.should_receive(:call).with('event', 'configure', expected_payload)

        @observer.send(:finish_system, @system)
      end

      it 'will call System#send_application_payload' do
        @system.should_receive(:send_application_payload)
        @observer.send(:finish_system, @system)
      end

      it 'will call System#deploy_applications' do
        @system.should_receive(:deploy_applications)
        @observer.send(:finish_system, @system)
      end

      it 'will request restore event to serf' do
        @serf_client.should_receive(:call).with('event', 'restore', {})
        @observer.send(:finish_system, @system)
      end
    end
  end
end
