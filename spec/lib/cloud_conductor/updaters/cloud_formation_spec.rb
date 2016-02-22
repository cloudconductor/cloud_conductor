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
  module Updaters
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
                                                                   FactoryGirl.build(:pattern_snapshot, type: 'optional')]
                                              )
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
                                                   { cloud_id: cloud_openstack.id, priority: 20 }]
                          )
      end

      before do
        @environment = Environment.eager_load(system: [:project]).find(environment)
        @platform_stack = FactoryGirl.build(:stack, pattern_snapshot: blueprint_history.pattern_snapshots.first, name: blueprint_history.pattern_snapshots.first.name, environment: @environment, status: :PENDING)
        @optional_stack = FactoryGirl.build(:stack, pattern_snapshot: blueprint_history.pattern_snapshots.last, name: blueprint_history.pattern_snapshots.last.name, environment: @environment, status: :PENDING)
        @environment.stacks += [@platform_stack, @optional_stack]
        @updater = CloudFormation.new cloud_aws, @environment
        allow_any_instance_of(Pattern).to receive(:clone_repository)
        allow(CloudConductor::Config).to receive_message_chain(:system_build, :timeout).and_return(1800)
      end

      describe '#initialize' do
        it 'set @cloud' do
          expect(@updater.instance_variable_get(:@cloud)).to eq(cloud_aws)
        end

        it 'set @environment' do
          expect(@updater.instance_variable_get(:@environment)).to eq(@environment)
        end
      end

      describe '#update_infrastructure' do
        before do
          allow_any_instance_of(Stack).to receive(:outputs)
          allow_any_instance_of(Stack).to receive(:progress?).and_return(true)
          allow_any_instance_of(Stack).to receive(:update_stack)

          allow(@updater).to receive(:get_nodes).and_return(['dummy_node'])
          allow(@updater).to receive(:wait_for_finished)
          allow(@updater).to receive(:update_environment)
        end

        it 'keep previous nodes' do
          @updater.send(:update_infrastructure)
          expect(@updater.instance_variable_get(:@nodes)).to eq(['dummy_node'])
        end

        it 'create all stacks' do
          @updater.send(:update_infrastructure)
          expect(@environment.stacks.all?(&:create_complete?)).to be_truthy
        end

        it 'set status of stacks to :ERROR when some method raise error' do
          allow(@updater).to receive(:wait_for_finished).and_raise
          expect { @updater.send(:update_infrastructure) }.to raise_error RuntimeError

          expect(@environment.stacks.all?(&:error?)).to be_truthy
        end

        it 'doesn\'t call #wait_for_finished and #update_environment if pattern doesn\'t contain template.json' do
          allow_any_instance_of(Stack).to receive(:progress?).and_return(false)
          expect(@updater).not_to receive(:wait_for_finished)
          expect(@updater).not_to receive(:update_environment)
          @updater.send(:update_infrastructure)
        end
      end

      describe '#wait_for_finished' do
        before do
          allow(@updater).to receive(:sleep)

          allow(@platform_stack).to receive(:status).and_return(:UPDATE_COMPLETE)
          allow(@platform_stack).to receive(:outputs).and_return('ConsulAddresses' => '127.0.0.1')

          allow(@optional_stack).to receive(:status).and_return(:UPDATE_COMPLETE)
          allow(@optional_stack).to receive(:outputs).and_return('ConsulAddresses' => '127.0.0.1')
        end

        it 'execute without error' do
          @updater.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD)
        end

        it 'raise error when timeout' do
          expect { @updater.send(:wait_for_finished, @platform_stack, 0) }.to raise_error(RuntimeError)
        end

        it 'raise error when target stack is already deleted' do
          @platform_stack.destroy
          expect { @updater.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
        end

        it 'raise error when some error occurred while update stack' do
          allow(@platform_stack).to receive(:status).and_return(:ERROR)
          expect { @updater.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
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
          expect { @updater.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(/dummy error message/)
        end

        it 'infinity loop and timeout while status still :UPDATE_IN_PROGRESS' do
          allow(@platform_stack).to receive(:status).and_return(:UPDATE_IN_PROGRESS)
          expect { @updater.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
        end

        it 'infinity loop and timeout while outputs doesn\'t have ConsulAddresses on platform stack' do
          allow(@platform_stack).to receive(:outputs).and_return(dummy: 'value')
          expect { @updater.send(:wait_for_finished, @platform_stack, CloudFormation::CHECK_PERIOD) }.to raise_error(RuntimeError)
        end

        it 'return successfully when outputs doesn\'t have ConsulAddresses on optional stack' do
          allow(@optional_stack).to receive(:outputs).and_return(dummy: 'value')
          @updater.send(:wait_for_finished, @optional_stack, CloudFormation::CHECK_PERIOD)
        end
      end

      describe '#update_environment' do
        it 'update environment when outputs exists' do
          outputs = {
            'FrontendAddress' => '127.0.0.1',
            'ConsulAddresses' => '192.168.0.1, 192.168.0.2',
            'dummy' => 'value'
          }

          @updater.send(:update_environment, outputs)

          expect(@environment.frontend_address).to eq('127.0.0.1')
          expect(@environment.consul_addresses).to eq('192.168.0.1, 192.168.0.2')
          expect(@environment.platform_outputs).to eq('{"dummy":"value"}')
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
          allow(@environment).to receive_message_chain(:consul, :catalog, :nodes).and_return [{ node: 'dummy_node' }]

          result = @updater.send(:get_nodes, @environment)
          expect(result).to eq(['dummy_node'])
        end
      end
    end
  end
end
