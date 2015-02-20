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
    include_context 'default_resources'

    before do
      platform_pattern = FactoryGirl.create(:pattern, :platform)
      optional_pattern = FactoryGirl.create(:pattern, :optional)
      blueprint = FactoryGirl.create(:blueprint, patterns: [platform_pattern, optional_pattern])
      @environment = FactoryGirl.build(:environment, blueprint: blueprint)

      @platform_stack = FactoryGirl.build(:stack, pattern: platform_pattern, name: platform_pattern.name, environment: @environment)
      @optional_stack = FactoryGirl.build(:stack, pattern: optional_pattern, name: optional_pattern.name, environment: @environment)
      @environment.stacks.delete_all
      @environment.stacks << @platform_stack
      @environment.stacks << @optional_stack
      @environment.save!

      @builder = SystemBuilder.new @environment

      Stack.skip_callback :save, :before, :create_stack
      Stack.skip_callback :destroy, :before, :destroy_stack
    end

    after do
      Stack.set_callback :save, :before, :create_stack, if: -> { ready? }
      Stack.set_callback :destroy, :before, :destroy_stack, unless: -> { pending? }
    end

    describe '#initialize' do
      it 'set @clouds that contains candidate clouds orderd by priority' do
        @environment.candidates[0].update_attributes(priority: 10)
        @environment.candidates[1].update_attributes(priority: 20)
        builder = SystemBuilder.new @environment
        clouds = builder.instance_variable_get :@clouds
        expect(clouds).to eq([@environment.clouds.last, @environment.clouds.first])

        @environment.candidates[0].update_attributes(priority: 20)
        @environment.candidates[1].update_attributes(priority: 10)
        builder = SystemBuilder.new @environment
        clouds = builder.instance_variable_get :@clouds
        expect(clouds).to eq([@environment.clouds.first, @environment.clouds.last])
      end

      it 'set @environment' do
        environment = @builder.instance_variable_get :@environment
        expect(environment).to eq(@environment)
      end
    end

    describe '#build' do
      before do
        allow_any_instance_of(Stack).to receive(:outputs).and_return(key: 'dummy')

        allow(@builder).to receive(:wait_for_finished)
        allow(@builder).to receive(:update_environment)
        allow(@builder).to receive(:finish_environment) { @environment.status = :CREATE_COMPLETE }
        allow(@builder).to receive(:reset_stacks)
      end

      it 'call every subsequence 1 time' do
        expect(@builder).to receive(:wait_for_finished).with(@environment.stacks[0], anything).ordered
        expect(@builder).to receive(:update_environment).with(key: 'dummy').ordered
        expect(@builder).to receive(:wait_for_finished).with(@environment.stacks[1], anything).ordered
        expect(@builder).to receive(:finish_environment).ordered
        expect(@builder).not_to receive(:reset_stacks)
        @builder.build
      end

      it 'call #reset_stacks when some method raise error' do
        allow(@builder).to receive(:wait_for_finished).with(@environment.stacks[0], anything).and_raise
        expect(@builder).to receive(:reset_stacks)
        @builder.build
      end

      it 'create all stacks' do
        @builder.build
        expect(@environment.stacks.all?(&:create_complete?)).to be_truthy
      end

      it 'set status of stacks to :ERROR when all candidates failed' do
        allow(@environment).to receive(:status).and_return(:ERROR)
        @builder.build

        expect(@environment.stacks.all?(&:error?)).to be_truthy
      end
    end

    describe '#wait_for_finished' do
      before do
        allow(@builder).to receive(:sleep)

        allow(@platform_stack).to receive(:status).and_return(:CREATE_COMPLETE)
        allow(@platform_stack).to receive(:outputs).and_return('FrontendAddress' => '127.0.0.1')

        allow(@optional_stack).to receive(:status).and_return(:CREATE_COMPLETE)
        allow(@optional_stack).to receive(:outputs).and_return('FrontendAddress' => '127.0.0.1')

        allow(Consul::Client).to receive_message_chain(:new, :running?).and_return true
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
        allow(Consul::Client).to receive_message_chain(:new, :running?).and_return false
        expect { @builder.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD) }.to raise_error
      end
    end

    describe '#update_environment' do
      before do
        Environment.skip_callback :save, :before, :enable_monitoring
        Environment.skip_callback :save, :before, :update_dns
      end

      after do
        Environment.set_callback :save, :before, :enable_monitoring, if: -> { monitoring_host_changed? }
        Environment.set_callback :save, :before, :update_dns, if: -> { ip_address }
      end

      it 'update environment when outputs exists' do
        outputs = {
          'FrontendAddress' => '127.0.0.1',
          'dummy' => 'value'
        }

        @builder.send(:update_environment, outputs)

        expect(@environment.ip_address).to eq('127.0.0.1')
        expect(@environment.monitoring_host).to eq('example.com')
        expect(@environment.template_parameters).to eq('{"dummy":"value"}')
      end
    end

    describe '#finish_environment' do
      before do
        @event = double(:event, sync_fire: 1)
        allow(@environment).to receive(:event).and_return(@event)
        allow(@builder).to receive(:configure_payload).and_return({})
        allow(@builder).to receive(:application_payload).and_return({})
      end

      it 'will request configure event to consul' do
        expect(@event).to receive(:sync_fire).with(:configure, {})
        @builder.send(:finish_environment)
      end

      it 'will request restore event to consul' do
        expect(@event).to receive(:sync_fire).with(:restore, {})
        @builder.send(:finish_environment)
      end

      it 'won\'t request deploy event to consul when create new environment' do
        expect(@event).not_to receive(:sync_fire).with(:deploy, anything)
        @builder.send(:finish_environment)
      end

      it 'will request deploy event to consul when create already deploymented environment' do
        @environment.deployments << FactoryGirl.create(:deployment, environment: @environment, application_history: application_history)
        expect(@event).to receive(:sync_fire).with(:deploy, {})
        @builder.send(:finish_environment)
      end

      it 'change application history status if deploy event is finished' do
        @environment.deployments << FactoryGirl.create(:deployment, environment: @environment, application_history: application_history)
        expect(@environment.deployments.first.status).to eq(:NOT_YET)

        @builder.send(:finish_environment)

        expect(@environment.deployments.first.status).to eq(:DEPLOYED)
      end
    end

    describe '#configure_payload' do
      it 'return payload that contains random salt' do
        payload = @builder.send(:configure_payload, @environment)
        expect(payload[:cloudconductor][:salt]).to match(/[0-9a-f]{32}/)
      end

      it 'will request configure event to serf with payload' do
        @platform_stack.status = :CREATE_COMPLETE
        @platform_stack.save!

        @optional_stack.status = :CREATE_COMPLETE
        @optional_stack.save!

        payload = @builder.send(:configure_payload, @environment)
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
    end

    describe '#reset_stacks' do
      before do
        allow(@environment).to receive(:destroy_stacks) do
          @environment.stacks.each(&:delete)
        end
      end

      it 'destroy previous stacks and re-create stacks with PENDING status' do
        stack = @environment.stacks.first
        stack.status = :CREATE_COMPLETE
        stack.save!

        expect { @builder.send(:reset_stacks) }.not_to change { Stack.count }
        expect(@environment.stacks.first).not_to eq(stack)
        expect(Stack.all.all?(&:pending?)).to be_truthy
      end

      it 'reset ip_address, monitoring_host and template_parameters in environment' do
        @environment.ip_address = '127.0.0.1'
        @environment.monitoring_host = 'example.com'
        @environment.template_parameters = '{ "key": "dummy" }'

        @builder.send(:reset_stacks)

        expect(@environment.ip_address).to be_nil
        expect(@environment.monitoring_host).to be_nil
        expect(@environment.template_parameters).to eq('{}')
      end

      it 'change status of environment to :ERROR when some error occurred' do
        @builder.send(:reset_stacks)
        expect(@environment.status).to eq(:ERROR)
      end
    end

    describe '#configure_payload' do
      it 'return payload that used for configure event' do
        allow(@environment.stacks).to receive(:created).and_return([@platform_stack, @optional_stack])

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

        expect(@builder.send(:configure_payload, @environment)).to expected_payload
      end
    end

    describe '#application_payload' do
      it 'return empty payload when deployments are empty' do
        expect(@builder.send(:application_payload, @environment)).to eq({})
      end

      it 'return merged payload that contains all deployments' do
        application1 = FactoryGirl.create(:application, name: 'application1')
        application2 = FactoryGirl.create(:application, name: 'application2')
        history1 = FactoryGirl.create(:application_history, application: application1)
        history2 = FactoryGirl.create(:application_history, application: application2)

        @environment.deployments << FactoryGirl.create(:deployment, environment: @environment, application_history: history1)
        @environment.deployments << FactoryGirl.create(:deployment, environment: @environment, application_history: history2)
        expected_payload = satisfy do |payload|
          expect(payload[:cloudconductor][:applications].keys).to eq(%w(application1 application2))
        end

        expect(@builder.send(:application_payload, @environment)).to expected_payload
      end
    end
  end
end
