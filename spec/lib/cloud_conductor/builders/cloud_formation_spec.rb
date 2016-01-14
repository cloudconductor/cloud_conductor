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
  module Builders
    describe CloudFormation do
      include_context 'default_resources'

      let(:cloud_aws) { FactoryGirl.create(:cloud, :aws, project: project) }
      let(:cloud_openstack) { FactoryGirl.create(:cloud, :openstack, project: project) }
      let(:blueprint_history) do
        allow_any_instance_of(Pattern).to receive(:set_metadata_from_repository)
        @cloud = Cloud.eager_load(:project).find(cloud)

        blueprint_history = FactoryGirl.create(:blueprint_history,
                                               blueprint: blueprint,
                                               pattern_snapshots: [FactoryGirl.build(:pattern_snapshot, type: 'platform'),
                                                                   FactoryGirl.build(:pattern_snapshot, type: 'optional')])
        blueprint_history.pattern_snapshots.each do |pattern_snapshot|
          FactoryGirl.create(:image, pattern_snapshot: pattern_snapshot, base_image: base_image, cloud: @cloud, status: :CREATE_COMPLETE)
        end
        blueprint_history
      end
      let(:environment) do
        @blueprint_history = BlueprintHistory.eager_load(:pattern_snapshots).find(blueprint_history)
        FactoryGirl.create(:environment,
                           system: system,
                           blueprint_history: @blueprint_history,
                           candidates_attributes: [{ cloud_id: cloud_aws.id, priority: 10 },
                                                   { cloud_id: cloud_openstack.id, priority: 20 }])
      end

      before do
        @environment = Environment.eager_load(:system).find(environment)
        @platform_stack = FactoryGirl.build(:stack, pattern_snapshot: blueprint_history.pattern_snapshots.first, name: blueprint_history.pattern_snapshots.first.name, cloud: cloud_openstack, environment: @environment)
        @optional_stack = FactoryGirl.build(:stack, pattern_snapshot: blueprint_history.pattern_snapshots.last, name: blueprint_history.pattern_snapshots.last.name, cloud: cloud_openstack, environment: @environment)
        @environment.stacks += [@platform_stack, @optional_stack]
        @builder = CloudFormation.new cloud_aws, @environment
        allow_any_instance_of(Environment).to receive(:create_or_update_stack)
        allow_any_instance_of(Environment).to receive(:destroy_stack)
        allow_any_instance_of(Pattern).to receive(:execute_packer)
        allow_any_instance_of(Pattern).to receive(:clone_repository)
        allow_any_instance_of(Stack).to receive(:create_stack)
        allow(CloudConductor::Config).to receive_message_chain(:system_build, :timeout).and_return(1800)
      end

      describe '#initialize' do
        it 'set @clouds that contains candidate clouds orderd by priority' do
          @environment.candidates[0].update_columns(priority: 10)
          @environment.candidates[1].update_columns(priority: 20)
          builder = CloudFormation.new cloud, @environment
          clouds = builder.instance_variable_get :@clouds
          expect(clouds).to eq([@environment.clouds.last, @environment.clouds.first])

          @environment.candidates[0].update_columns(priority: 20)
          @environment.candidates[1].update_columns(priority: 10)
          builder = CloudFormation.new cloud, @environment
          clouds = builder.instance_variable_get :@clouds
          expect(clouds).to eq([@environment.clouds.first, @environment.clouds.last])
        end

        it 'set @cloud' do
          expect(@builder.instance_variable_get(:@cloud)).to eq(cloud_aws)
        end

        it 'set @environment' do
          expect(@builder.instance_variable_get(:@environment)).to eq(@environment)
        end
      end

      describe '#build_infrastructure' do
        before do
          allow_any_instance_of(Stack).to receive(:outputs).and_return(key: 'dummy')
          allow_any_instance_of(Stack).to receive(:progress?).and_return(true)

          allow(@builder).to receive(:wait_for_finished)
          allow(@builder).to receive(:update_environment)
          allow(@builder).to receive(:reset_stacks)
        end

        it 'call every subsequence 1 time' do
          expect(@builder).to receive(:wait_for_finished).with(@environment.stacks[0], anything).ordered
          expect(@builder).to receive(:update_environment).with(key: 'dummy').ordered
          expect(@builder).to receive(:wait_for_finished).with(@environment.stacks[1], anything).ordered
          expect(@builder).not_to receive(:reset_stacks)
          @builder.send(:build_infrastructure)
        end

        it 'call #reset_stacks when some method raise error' do
          allow(@builder).to receive(:wait_for_finished).with(@environment.stacks[0], anything).and_raise
          expect(@builder).to receive(:reset_stacks)
          expect { @builder.send(:build_infrastructure) }.to raise_error RuntimeError
        end

        it 'create all stacks' do
          @builder.send(:build_infrastructure)
          expect(@environment.stacks.all?(&:create_complete?)).to be_truthy
        end

        it 'doesn\'t call #wait_for_finished and #update_environment if pattern doesn\'t contain template.json' do
          allow_any_instance_of(Stack).to receive(:progress?).and_return(false)
          expect(@builder).not_to receive(:wait_for_finished)
          expect(@builder).not_to receive(:update_environment)
          @builder.send(:build_infrastructure)
        end
      end

      describe '#destroy_infrastructure' do
        before do
          pattern1 = FactoryGirl.build(:pattern_snapshot, type: 'optional', blueprint_history: blueprint_history)
          pattern2 = FactoryGirl.build(:pattern_snapshot, type: 'platform', blueprint_history: blueprint_history)
          pattern3 = FactoryGirl.build(:pattern_snapshot, type: 'optional', blueprint_history: blueprint_history)

          @environment.stacks.delete_all
          @environment.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, environment: @environment, pattern_snapshot: pattern1, cloud: cloud_aws)
          @environment.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, environment: @environment, pattern_snapshot: pattern2, cloud: cloud_aws)
          @environment.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, environment: @environment, pattern_snapshot: pattern3, cloud: cloud_aws)

          @environment.save!

          allow(@builder).to receive(:sleep)
          allow(@builder).to receive(:stack_destroyed?).and_return(-> (_) { true })

          allow_any_instance_of(Stack).to receive(:destroy)

          original_timeout = Timeout.method(:timeout)
          allow(Timeout).to receive(:timeout) do |_, &block|
            original_timeout.call(0.1, &block)
          end
        end

        it 'destroy all stacks of environment' do
          expect(@environment.stacks).not_to be_empty
          @builder.send(:destroy_infrastructure)
          expect(@environment.stacks).to be_empty
        end

        it 'destroy optional patterns before platform' do
          expect(@environment.stacks[0]).to receive(:destroy).ordered
          expect(@environment.stacks[2]).to receive(:destroy).ordered
          expect(@environment.stacks[1]).to receive(:destroy).ordered

          @builder.send(:destroy_infrastructure)
        end

        it 'doesn\'t destroy platform pattern until timeout if optional pattern can\'t destroy' do
          allow(@builder).to receive(:stack_destroyed?).and_return(-> (_) { false })

          expect(@environment.stacks[0]).to receive(:destroy).ordered
          expect(@environment.stacks[2]).to receive(:destroy).ordered
          expect(@builder).to receive(:sleep).at_least(:once).ordered
          expect(@environment.stacks[1]).to receive(:destroy).ordered

          @builder.send(:destroy_infrastructure)
        end

        it 'wait and destroy platform pattern when destroyed all optional patterns' do
          allow(@builder).to receive(:stack_destroyed?).and_return(-> (_) { false }, -> (_) { true })

          expect(@environment.stacks[0]).to receive(:destroy).ordered
          expect(@environment.stacks[2]).to receive(:destroy).ordered
          expect(@builder).to receive(:sleep).once.ordered
          expect(@environment.stacks[1]).to receive(:destroy).ordered

          @builder.send(:destroy_infrastructure)
        end

        it 'ensure destroy platform when some error occurred while destroying optional' do
          allow(@environment.stacks[0]).to receive(:destroy).and_raise(RuntimeError)
          expect(@environment.stacks[1]).to receive(:destroy)
          expect { @builder.send(:destroy_infrastructure) }.to raise_error(RuntimeError)
        end
      end

      describe '#wait_for_finished' do
        before do
          allow(@builder).to receive(:sleep)

          allow(@platform_stack).to receive(:status).and_return(:CREATE_COMPLETE)
          allow(@platform_stack).to receive(:outputs).and_return('FrontendAddress' => '127.0.0.1')
          allow(@platform_stack).to receive(:events).and_return([])

          allow(@optional_stack).to receive(:status).and_return(:CREATE_COMPLETE)
          allow(@optional_stack).to receive(:outputs).and_return('FrontendAddress' => '127.0.0.1')
          allow(@optional_stack).to receive(:events).and_return([])

          allow(Consul::Client).to receive_message_chain(:new, :running?).and_return true
        end

        it 'execute without error' do
          @builder.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD)
        end

        it 'raise error when timeout' do
          expect { @builder.send(:wait_for_finished, @platform_stack, 0) }.to raise_error(RuntimeError)
        end

        it 'raise error when target stack is already deleted' do
          @platform_stack.destroy
          expect { @builder.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
        end

        it 'raise error when some error occurred while create stack' do
          allow(@platform_stack).to receive(:status).and_return(:ERROR)
          expect { @builder.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
        end

        it 'include event message of stack in exception' do
          event = {
            timestamp: Time.now,
            resource_status: 'CREATE_FAILED',
            resource_type: 'dummy_type',
            logical_resource_id: 'dummy_resource_id',
            resource_status_reason: 'dummy error message'
          }
          allow(@platform_stack).to receive(:status).and_return(:ERROR)
          allow(@platform_stack).to receive(:events).and_return([event])
          expect { @builder.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(/dummy error message/)
        end

        it 'infinity loop and timeout while status still :CREATE_IN_PROGRESS' do
          allow(@platform_stack).to receive(:status).and_return(:CREATE_IN_PROGRESS)
          expect { @builder.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
        end

        it 'infinity loop and timeout while outputs doesn\'t have FrontendAddress on platform stack' do
          allow(@platform_stack).to receive(:outputs).and_return(dummy: 'value')
          expect { @builder.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
        end

        it 'return successfully when outputs doesn\'t have FrontendAddress on optional stack' do
          allow(@optional_stack).to receive(:outputs).and_return(dummy: 'value')
          @builder.send(:wait_for_finished, @optional_stack, CloudFormation::CHECK_PERIOD)
        end

        it 'infinity loop and timeout while consul doesn\'t running' do
          allow(Consul::Client).to receive_message_chain(:new, :running?).and_return false
          expect { @builder.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
        end
      end

      describe '#update_environment' do
        it 'update environment when outputs exists' do
          outputs = {
            'FrontendAddress' => '127.0.0.1',
            'dummy' => 'value'
          }

          @builder.send(:update_environment, outputs)

          expect(@environment.ip_address).to eq('127.0.0.1')
          expect(@environment.platform_outputs).to eq('{"dummy":"value"}')
        end
      end

      describe '#reset_stacks' do
        before do
          allow(@builder).to receive(:destroy_infrastructure) do
            @environment.stacks.each(&:delete)
          end
        end

        it 'destroy previous stacks and re-create stacks with PENDING status' do
          stack = @environment.stacks.first
          stack.status = :CREATE_COMPLETE
          stack.cloud = cloud_openstack
          stack.save!

          expect { @builder.send(:reset_stacks) }.not_to change { Stack.count }
          expect(@environment.stacks.first).not_to eq(stack)
          expect(Stack.all.all?(&:pending?)).to be_truthy
        end

        it 'reset ip_address and platform_outputs in environment' do
          @environment.ip_address = '127.0.0.1'
          @environment.platform_outputs = '{ "key": "dummy" }'

          @builder.send(:reset_stacks)

          expect(@environment.ip_address).to be_nil
          expect(@environment.platform_outputs).to eq('{}')
        end

        it 'change status of environment to :ERROR' do
          @builder.send(:reset_stacks)
          expect(@environment.status).to eq(:ERROR)
        end
      end
    end
  end
end
