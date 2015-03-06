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
  describe SystemUpdater do
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
      @environment.candidates << FactoryGirl.build(:candidate, environment: @environment)
      @environment.candidates << FactoryGirl.build(:candidate, environment: @environment)
      @environment.save!

      allow(@environment).to receive_message_chain(:consul, :catalog, :nodes).and_return [{ node: 'dummy_node' }]
      @updater = SystemUpdater.new @environment

      Stack.skip_callback :save, :before, :create_stack
      Stack.skip_callback :save, :before, :update_stack
      Stack.skip_callback :destroy, :before, :destroy_stack
    end

    after do
      Stack.set_callback :save, :before, :create_stack, if: -> { ready_for_create? }
      Stack.set_callback :save, :before, :update_stack, if: -> { ready_for_update? }
      Stack.set_callback :destroy, :before, :destroy_stack, unless: -> { pending? }
    end

    describe '#initialize' do
      it 'set @nodes' do
        nodes = @updater.instance_variable_get :@nodes
        expect(nodes).to eq(['dummy_node'])
      end

      it 'set @environment' do
        environment = @updater.instance_variable_get :@environment
        expect(environment).to eq(@environment)
      end
    end

    describe '#update' do
      before do
        allow_any_instance_of(Stack).to receive(:outputs).and_return(key: 'dummy')

        allow(@updater).to receive(:wait_for_finished)
        allow(@updater).to receive(:update_environment)
        allow(@updater).to receive(:finish_environment) { @environment.status = :CREATE_COMPLETE }
      end

      it 'call every subsequence 1 time' do
        expect(@updater).to receive(:wait_for_finished).with(@environment.stacks[0], anything).ordered
        expect(@updater).to receive(:update_environment).with(key: 'dummy').ordered
        expect(@updater).to receive(:wait_for_finished).with(@environment.stacks[1], anything).ordered
        expect(@updater).to receive(:finish_environment).ordered
        @updater.update
      end

      it 'create all stacks' do
        @updater.update
        expect(@environment.stacks.all?(&:create_complete?)).to be_truthy
      end

      it 'set status of stacks to :ERROR when all candidates failed' do
        allow(@environment).to receive(:status).and_return(:ERROR)
        @updater.update

        expect(@environment.stacks.all?(&:error?)).to be_truthy
      end
    end

    describe '#wait_for_finished' do
      before do
        allow(@updater).to receive(:sleep)

        allow(@platform_stack).to receive(:status).and_return(:UPDATE_COMPLETE)
        allow(@platform_stack).to receive(:outputs).and_return('FrontendAddress' => '127.0.0.1')

        allow(@optional_stack).to receive(:status).and_return(:UPDATE_COMPLETE)
        allow(@optional_stack).to receive(:outputs).and_return('FrontendAddress' => '127.0.0.1')

        allow(Consul::Client).to receive_message_chain(:new, :running?).and_return true
      end

      it 'execute without error' do
        @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD)
      end

      it 'raise error when timeout' do
        expect { @updater.send(:wait_for_finished, @platform_stack, 0) }.to raise_error
      end

      it 'raise error when target stack is already deleted' do
        @platform_stack.destroy
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error
      end

      it 'raise error when timeout' do
        allow(@platform_stack).to receive(:status).and_return(:ERROR)
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error
      end

      it 'infinity loop and timeout while status still :UPDATE_IN_PROGRESS' do
        allow(@platform_stack).to receive(:status).and_return(:UPDATE_IN_PROGRESS)
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error
      end

      it 'infinity loop and timeout while outputs doesn\'t have FrontendAddress on platform stack' do
        allow(@platform_stack).to receive(:outputs).and_return(dummy: 'value')
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error
      end

      it 'return successfuly when outputs doesn\'t have FrontendAddress on optional stack' do
        allow(@optional_stack).to receive(:outputs).and_return(dummy: 'value')
        @updater.send(:wait_for_finished, @optional_stack, SystemUpdater::CHECK_PERIOD)
      end

      it 'infinity loop and timeout while consul doesn\'t running' do
        allow(Consul::Client).to receive_message_chain(:new, :running?).and_return false
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error
      end
    end

    describe '#update_environment' do
      it 'update environment when outputs exists' do
        outputs = {
          'FrontendAddress' => '127.0.0.1',
          'dummy' => 'value'
        }

        @updater.send(:update_environment, outputs)

        expect(@environment.ip_address).to eq('127.0.0.1')
        expect(@environment.template_parameters).to eq('{"dummy":"value"}')
      end
    end

    describe '#finish_environment' do
      before do
        @event = double(:event, sync_fire: 1)
        allow(@environment).to receive(:event).and_return(@event)
        allow(@environment).to receive_message_chain(:consul, :catalog, :nodes).and_return [{ node: 'dummy_node' }, { node: 'sample_node' }]
      end

      it 'will request configure event to consul' do
        expect(@event).to receive(:sync_fire).with(:configure)
        @updater.send(:finish_environment)
      end

      it 'will request restore event to consul' do
        expect(@event).to receive(:sync_fire).with(:restore, {}, node: ['sample_node'])
        @updater.send(:finish_environment)
      end

      it 'won\'t request deploy event to consul when create new environment' do
        expect(@event).not_to receive(:sync_fire).with(:deploy, anything, anything)
        @updater.send(:finish_environment)
      end

      it 'will request deploy event to consul when create already deploymented environment' do
        FactoryGirl.create(:deployment, environment: @environment, application_history: application_history)
        expect(@event).to receive(:sync_fire).with(:deploy, {}, node: ['sample_node'])
        @updater.send(:finish_environment)
      end

      it 'change application history status if deploy event is finished' do
        FactoryGirl.create(:deployment, environment: @environment, application_history: application_history)

        expect_any_instance_of(Deployment).to receive(:update_status).at_least(1)
        @updater.send(:finish_environment)
      end
    end
  end
end
