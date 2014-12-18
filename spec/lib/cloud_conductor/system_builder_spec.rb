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
  describe SystemBuilder do
    before do
      @platform_stack = FactoryGirl.create(:stack, pattern: FactoryGirl.create(:pattern, type: :platform))
      @optional_stack = FactoryGirl.create(:stack, pattern: FactoryGirl.create(:pattern, type: :optional))

      @system = FactoryGirl.create(:system)
      @system.stacks << @platform_stack
      @system.stacks << @optional_stack
      @system.candidates[0].priority = 10
      @system.candidates[1].priority = 20

      @builder = SystemBuilder.new @system

      Stack.skip_callback :save, :before, :create_stack
      Stack.skip_callback :destroy, :before, :destroy_stack
    end

    after do
      Stack.set_callback :save, :before, :create_stack, if: -> { ready? }
      Stack.set_callback :destroy, :before, :destroy_stack, unless: -> { pending? }
    end

    describe '#initialize' do
      it 'set @clouds that contains candidate clouds orderd by priority' do
        clouds = @builder.instance_variable_get :@clouds
        expect(clouds).to eq([@system.clouds.last, @system.clouds.first])
      end

      it 'set @system' do
        system = @builder.instance_variable_get :@system
        expect(system).to eq(@system)
      end
    end

    describe '#build' do
      before do
        allow_any_instance_of(Stack).to receive(:outputs).and_return(key: 'dummy')

        allow(@builder).to receive(:wait_for_finished)
        allow(@builder).to receive(:update_system)
        allow(@builder).to receive(:finish_system)
        allow(@builder).to receive(:reset_stacks)
      end

      it 'call every subsequence 1 time' do
        expect(@builder).to receive(:wait_for_finished).with(@system.stacks[0], anything)
        expect(@builder).to receive(:wait_for_finished).with(@system.stacks[1], anything)
        expect(@builder).to receive(:update_system).with(key: 'dummy')
        expect(@builder).to receive(:finish_system)
        expect(@builder).not_to receive(:reset_stacks)
        @builder.build
      end

      it 'call #reset_stacks when some method raise error' do
        expect(@builder).to receive(:wait_for_finished).with(@system.stacks[0], anything).and_raise
        expect(@builder).to receive(:reset_stacks)
        @builder.build
      end

      it 'create all stacks' do
        @builder.build
        expect(@system.stacks.all?(&:create_complete?)).to be_truthy
      end

      it 'set status of stacks to :ERROR when all candidates failed' do
        expect(@builder).to receive(:wait_for_finished).with(@system.stacks[0], anything).and_raise
        allow(@builder).to receive(:wait_for_finished).with(@system.stacks[0], anything).and_raise
        @builder.build

        expect(@system.stacks.all?(&:error?)).to be_truthy
      end
    end

    describe '#wait_for_finished' do
      before do
        allow(@builder).to receive(:sleep)

        allow(@platform_stack).to receive(:status).and_return(:CREATE_COMPLETE)
        allow(@platform_stack).to receive(:outputs).and_return('FrontendAddress' => '127.0.0.1')

        allow(@optional_stack).to receive(:status).and_return(:CREATE_COMPLETE)
        allow(@optional_stack).to receive(:outputs).and_return('FrontendAddress' => '127.0.0.1')

        allow(Consul::Client).to receive_message_chain(:connect, :running?).and_return true
        allow(Serf::Client).to receive_message_chain(:new, :call, :success?).and_return true
      end

      it 'execute without error' do
        @builder.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD)
      end

      it 'raise error when timeout' do
        expect { @builder.send(:wait_for_finished, @platform_stack, 0) }.to raise_error
      end

      it 'raise error when target stack is already deleted' do
        @platform_stack.destroy
        expect { @builder.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD) }.to raise_error
      end

      it 'raise error when timeout' do
        allow(@platform_stack).to receive(:status).and_return(:ERROR)
        expect { @builder.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD) }.to raise_error
      end

      it 'infinity loop and timeout while status still :CREATE_IN_PROGRESS' do
        allow(@platform_stack).to receive(:status).and_return(:CREATE_IN_PROGRESS)
        expect { @builder.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD) }.to raise_error
      end

      it 'infinity loop and timeout while outputs doesn\'t have FrontendAddress on platform stack' do
        allow(@platform_stack).to receive(:outputs).and_return(dummy: 'value')
        expect { @builder.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD) }.to raise_error
      end

      it 'return successfuly when outputs doesn\'t have FrontendAddress on optional stack' do
        allow(@optional_stack).to receive(:outputs).and_return(dummy: 'value')
        @builder.send(:wait_for_finished, @optional_stack, SystemBuilder::CHECK_PERIOD)
      end

      it 'infinity loop and timeout while consul doesn\'t running' do
        allow(Consul::Client).to receive_message_chain(:connect, :running?).and_return false
        expect { @builder.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD) }.to raise_error
      end

      it 'infinity loop and timeout while serf doesn\'t running' do
        allow(Serf::Client).to receive_message_chain(:new, :call, :success?).and_return false
        expect { @builder.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD) }.to raise_error
      end
    end

    describe '#update_system' do
      before do
        System.skip_callback :save, :before, :enable_monitoring
        System.skip_callback :save, :before, :update_dns
      end

      after do
        System.set_callback :save, :before, :enable_monitoring, if: -> { monitoring_host_changed? }
        System.set_callback :save, :before, :update_dns, if: -> { ip_address }
      end

      it 'update system when outputs exists' do
        outputs = {
          'FrontendAddress' => '127.0.0.1',
          'dummy' => 'value'
        }

        @builder.send(:update_system, outputs)

        expect(@system.ip_address).to eq('127.0.0.1')
        expect(@system.monitoring_host).to eq('example.com')
        expect(@system.template_parameters).to eq('{"dummy":"value"}')
      end
    end

    describe '#finish_system' do
      before do
        @platform_stack.status = :CREATE_COMPLETE
        @platform_stack.save!

        @optional_stack.status = :CREATE_COMPLETE
        @optional_stack.save!

        @serf_client = double(:serf_client, call: double('status', success?: true))
        allow(@system).to receive(:serf).and_return(@serf_client)
        allow(@system).to receive(:send_application_payload)
        allow(@system).to receive(:deploy_applications)

        allow(@builder).to receive(:sleep)
      end

      it 'will request configure event with random seed' do
        expected_payload = satisfy do |payload|
          expect(payload[:cloudconductor][:seed]).to match(/[0-9a-f]{32}/)
        end

        expect(@serf_client).to receive(:call).with('event', 'configure', expected_payload)

        @builder.send(:finish_system)
      end

      it 'will request configure event to serf with payload' do
        expected_payload = satisfy do |payload|
          expect(payload[:cloudconductor][:patterns].keys).to eq([@platform_stack.pattern.name, @optional_stack.pattern.name])

          payload1 = payload[:cloudconductor][:patterns][@platform_stack.pattern.name]
          expect(payload1[:name]).to eq(@platform_stack.pattern.name)
          expect(payload1[:type]).to eq(@platform_stack.pattern.type.to_s)
          expect(payload1[:protocol]).to eq(@platform_stack.pattern.protocol.to_s)
          expect(payload1[:url]).to eq(@platform_stack.pattern.url)
          expect(payload1[:user_attributes]).to eq(JSON.parse(@platform_stack.parameters, symbolize_names: true))

          payload2 = payload[:cloudconductor][:patterns][@optional_stack.pattern.name]
          expect(payload2[:name]).to eq(@optional_stack.pattern.name)
          expect(payload2[:type]).to eq(@optional_stack.pattern.type.to_s)
          expect(payload2[:protocol]).to eq(@optional_stack.pattern.protocol.to_s)
          expect(payload2[:url]).to eq(@optional_stack.pattern.url)
          expect(payload2[:user_attributes]).to eq(JSON.parse(@optional_stack.parameters, symbolize_names: true))
        end

        expect(@serf_client).to receive(:call).with('event', 'configure', expected_payload)

        @builder.send(:finish_system)
      end

      it 'will call System#send_application_payload' do
        expect(@system).to receive(:send_application_payload)
        @builder.send(:finish_system)
      end

      it 'will call System#deploy_applications' do
        expect(@system).to receive(:deploy_applications)
        @builder.send(:finish_system)
      end

      it 'will request restore event to serf' do
        expect(@serf_client).to receive(:call).with('event', 'restore', {})
        @builder.send(:finish_system)
      end
    end

    describe '#reset_stacks' do
      before do
        allow(@system).to receive(:destroy_stacks) do
          @system.stacks.destroy_all
        end
      end

      it 'destroy previous stacks and re-create stacks with PENDING status' do
        expect(Stack.count).to eq(2)
        @builder.send(:reset_stacks)
        expect(Stack.count).to eq(2)
        expect(Stack.all.all?(&:pending?)).to be_truthy
      end

      it 'reset ip_address, monitoring_host and template_parameters in system' do
        @system.ip_address = '127.0.0.1'
        @system.monitoring_host = 'example.com'
        @system.template_parameters = '{ "key": "dummy" }'

        @builder.send(:reset_stacks)

        expect(@system.ip_address).to be_nil
        expect(@system.monitoring_host).to be_nil
        expect(@system.template_parameters).to eq('{}')
      end
    end
  end
end
