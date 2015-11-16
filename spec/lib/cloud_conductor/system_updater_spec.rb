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

    let(:cloud_aws) { FactoryGirl.create(:cloud, :aws) }
    let(:cloud_openstack) { FactoryGirl.create(:cloud, :openstack) }
    let(:blueprint_history) do
      allow_any_instance_of(Pattern).to receive(:set_metadata_from_repository)
      blueprint_history = FactoryGirl.create(:blueprint_history,
                                             blueprint: blueprint,
                                             pattern_snapshots: [FactoryGirl.create(:pattern_snapshot, type: 'platform'),
                                                                 FactoryGirl.create(:pattern_snapshot, type: 'optional')]
                                            )
      blueprint_history.pattern_snapshots.each do |pattern_snapshot|
        FactoryGirl.create(:image, pattern_snapshot: pattern_snapshot, base_image: base_image, cloud: cloud, status: :CREATE_COMPLETE)
      end
      blueprint_history
    end
    let(:environment) do
      FactoryGirl.create(:environment,
                         system: system,
                         blueprint_history: blueprint_history,
                         candidates_attributes: [{ cloud_id: cloud_aws.id, priority: 10 },
                                                 { cloud_id: cloud_openstack.id, priority: 20 }]
                        )
    end

    before do
      @environment = environment
      allow(@environment).to receive_message_chain(:consul, :catalog, :nodes).and_return [{ node: 'dummy_node' }]
      @platform_stack = FactoryGirl.build(:stack, pattern_snapshot: blueprint_history.pattern_snapshots.first, name: blueprint_history.pattern_snapshots.first.name, environment: @environment, status: :PENDING)
      @optional_stack = FactoryGirl.build(:stack, pattern_snapshot: blueprint_history.pattern_snapshots.last, name: blueprint_history.pattern_snapshots.last.name, environment: @environment, status: :PENDING)
      @environment.stacks += [@platform_stack, @optional_stack]
      @updater = SystemUpdater.new @environment
      allow_any_instance_of(Pattern).to receive(:clone_repository)
      allow_any_instance_of(Stack).to receive(:update_stack)
      allow(CloudConductor::Config).to receive_message_chain(:system_build, :timeout).and_return(1800)
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
        allow(@environment).to receive(:create_or_update_stacks) do
          @environment.stacks.each do |stack|
            stack.update_columns(status: :CREATE_COMPLETE)
          end
        end
        allow(@updater).to receive(:wait_for_finished)
        allow(@updater).to receive(:update_environment)
        allow(@updater).to receive(:finish_environment) { @environment.status = :CREATE_COMPLETE }
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
        expect { @updater.send(:wait_for_finished, @platform_stack, 0) }.to raise_error(RuntimeError)
      end

      it 'raise error when target stack is already deleted' do
        @platform_stack.destroy
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error(RuntimeError)
      end

      it 'raise error when some error occurred while update stack' do
        allow(@platform_stack).to receive(:status).and_return(:ERROR)
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error(RuntimeError)
      end

      it 'include event message of stack in exception' do
        event = double(
          'event',
          timestamp: Time.now,
          resource_status: 'UPDATE_FAILED',
          resource_type: 'dummy_type',
          logical_resource_id: 'dummy_resource_id',
          resource_status_reason: 'dummy error message'
        )
        allow(@platform_stack).to receive(:status).and_return(:ERROR)
        allow(@platform_stack).to receive(:events).and_return([event])
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemBuilder::CHECK_PERIOD) }.to raise_error(/dummy error message/)
      end

      it 'infinity loop and timeout while status still :UPDATE_IN_PROGRESS' do
        allow(@platform_stack).to receive(:status).and_return(:UPDATE_IN_PROGRESS)
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error(RuntimeError)
      end

      it 'infinity loop and timeout while outputs doesn\'t have FrontendAddress on platform stack' do
        allow(@platform_stack).to receive(:outputs).and_return(dummy: 'value')
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error(RuntimeError)
      end

      it 'return successfully when outputs doesn\'t have FrontendAddress on optional stack' do
        allow(@optional_stack).to receive(:outputs).and_return(dummy: 'value')
        @updater.send(:wait_for_finished, @optional_stack, SystemUpdater::CHECK_PERIOD)
      end

      it 'infinity loop and timeout while consul doesn\'t running' do
        allow(Consul::Client).to receive_message_chain(:new, :running?).and_return false
        expect { @updater.send(:wait_for_finished, @platform_stack, SystemUpdater::CHECK_PERIOD) }.to raise_error(RuntimeError)
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
        expect(@environment.platform_outputs).to eq('{"dummy":"value"}')
      end
    end

    describe '#finish_environment' do
      before do
        @event = double(:event, sync_fire: 1)
        allow(@environment).to receive(:event).and_return(@event)
        allow(@environment).to receive_message_chain(:consul, :catalog, :nodes).and_return [{ node: 'dummy_node' }, { node: 'sample_node' }]
        allow(@updater).to receive(:configure_payload).and_return({})
      end

      it 'will request configure event to consul' do
        expect(@event).to receive(:sync_fire).with(:configure, {})
        @updater.send(:finish_environment)
      end

      it 'will request restore event to consul' do
        expect(@event).to receive(:sync_fire).with(:restore, {}, node: ['sample_node'])
        @updater.send(:finish_environment)
      end

      it 'won\'t request deploy event to consul if environment hasn\'t deployment' do
        expect(@event).not_to receive(:sync_fire).with(:deploy, anything, anything)
        @updater.send(:finish_environment)
      end

      it 'will request deploy event to consul when create already deployed environment' do
        @environment.status = :CREATE_COMPLETE
        FactoryGirl.create(:deployment, environment: @environment, application_history: application_history)
        @environment.status = :PROGRESS

        expect(@event).to receive(:sync_fire).with(:deploy, {}, node: ['sample_node'])
        @updater.send(:finish_environment)
      end

      it 'change application history status if deploy event is finished' do
        @environment.status = :CREATE_COMPLETE
        FactoryGirl.create(:deployment, environment: @environment, application_history: application_history)
        @environment.status = :PROGRESS

        expect(@environment.deployments.first.status).to eq('NOT_DEPLOYED')
        @updater.send(:finish_environment)
        expect(@environment.deployments.first.status).to eq('DEPLOY_COMPLETE')
      end
    end

    describe '#configure_payload' do
      it 'return payload hash to use configure event' do
        expected_payload = {
          cloudconductor: {
            patterns: {
            }
          }
        }
        expected_payload[:cloudconductor][:patterns].deep_merge! @environment.stacks.first.payload

        @environment.stacks.first.status = :CREATE_COMPLETE
        @environment.stacks.first.save!
        result = @updater.send(:configure_payload, @environment)
        expect(result).to eq(expected_payload)
      end
    end

    describe '#get_nodes' do
      it 'return node list for consul catalog' do
        result = @updater.send(:get_nodes, @environment)
        expect(result).to eq(['dummy_node'])
      end
    end
  end
end
