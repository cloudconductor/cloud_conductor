require 'cloud_conductor/builders/builder'

module CloudConductor
  module Builders
    describe Builder do
      include_context 'default_resources'

      before do
        @builder = Builder.new(cloud, environment)
      end

      describe '#new' do
        it 'keep @cloud' do
          expect(@builder.instance_variable_get(:@cloud)).to eq(cloud)
        end

        it 'keep @environment' do
          expect(@builder.instance_variable_get(:@environment)).to eq(environment)
        end
      end

      describe '#build' do
        before do
          allow(@builder).to receive(:build_infrastructure)
          allow(@builder).to receive(:send_events)
        end

        it 'call subroutines that can override in child classes' do
          expect(@builder).to receive(:build_infrastructure)
          expect(@builder).to receive(:send_events)
          @builder.build
        end

        it 'update environment status to :CREATE_COMPLETE without error' do
          @builder.build
          expect(environment.status).to eq(:CREATE_COMPLETE)
        end

        it 'raise error and update environment status to :ERROR when some error has been occurred' do
          allow(@builder).to receive(:build_infrastructure).and_raise
          expect { @builder.build }.to raise_error(RuntimeError)
          expect(environment.status).to eq(:ERROR)
        end
      end

      describe '#destroy' do
        before do
          allow(@builder).to receive(:destroy_infrastructure)
        end

        it 'call subroutines that can be overridden in child classes' do
          expect(@builder).to receive(:destroy_infrastructure)
          @builder.destroy
        end

        it 'raise error and update environment status to :ERROR when some error has been occurred' do
          allow(@builder).to receive(:destroy_infrastructure).and_raise
          expect { @builder.destroy }.to raise_error(RuntimeError)
          expect(environment.status).to eq(:ERROR)
        end
      end

      describe '#build_infrastructure' do
        it 'raise exception when call don\'t overrided build_infrastructure' do
          allow(@builder).to receive(:build_infrastructure).and_call_original
          expect { @builder.send(:build_infrastructure) }.to raise_error(RuntimeError)
        end
      end

      describe '#destroy_infrastructure' do
        it 'raise exception when call don\'t overrided destroy_infrastructure' do
          allow(@builder).to receive(:destroy_infrastructure).and_call_original
          expect { @builder.send(:destroy_infrastructure) }.to raise_error(RuntimeError)
        end
      end

      describe '#send_events' do
        before do
          @event = double(:event, sync_fire: 1)
          allow(environment).to receive(:event).and_return(@event)
          allow(@builder).to receive(:configure_payload).and_return({})
          allow(@builder).to receive(:application_payload).and_return({})
        end

        it 'will request configure event to consul' do
          expect(@event).to receive(:sync_fire).with(:configure, {})
          @builder.send(:send_events, environment)
        end

        it 'will request restore event to consul' do
          expect(@event).to receive(:sync_fire).with(:restore, {})
          @builder.send(:send_events, environment)
        end

        it 'won\'t request deploy event to consul when create new environment' do
          expect(@event).not_to receive(:sync_fire).with(:deploy, anything)
          @builder.send(:send_events, environment)
        end

        it 'will request deploy event to consul when create already deploymented environment' do
          environment.status = :CREATE_COMPLETE
          FactoryGirl.create(:deployment, environment: environment, application_history: application_history)

          expect(@event).to receive(:sync_fire).with(:deploy, {})
          @builder.send(:send_events, environment)
        end

        it 'will request spec event to consul' do
          expect(@event).to receive(:sync_fire).with(:spec)
          @builder.send(:send_events, environment)
        end

        it 'change application history status if deploy event is finished' do
          environment.status = :CREATE_COMPLETE
          FactoryGirl.create(:deployment, environment: environment, application_history: application_history)

          expect(environment.deployments.first.status).to eq('NOT_DEPLOYED')
          @builder.send(:send_events, environment)
          expect(environment.deployments.first.status).to eq('DEPLOY_COMPLETE')
        end
      end

      describe '#configure_payload' do
        before do
          environment.stacks.each { |stack| stack.update_attributes(status: :CREATE_COMPLETE) }
        end

        it 'return payload that contains random salt' do
          key = 'cloudconductor/cloudconductor'
          payload = @builder.send(:configure_payload, environment)[key]
          expect(payload[:cloudconductor][:salt]).to match(/^[0-9a-f]{64}$/)
        end

        it 'will request configure event to serf with payload' do
          stack1 = FactoryGirl.build(:stack, status: :CREATE_COMPLETE, parameters: '{ "key1": "value1" }')
          stack2 = FactoryGirl.build(:stack, status: :CREATE_COMPLETE, parameters: '{ "key2": "value2" }')
          environment.stacks << stack1
          environment.stacks << stack2
          environment.save!

          payload = @builder.send(:configure_payload, environment)

          key1 = "cloudconductor/patterns/#{stack1.pattern_snapshot.name}/attributes"
          key2 = "cloudconductor/patterns/#{stack2.pattern_snapshot.name}/attributes"
          expect(payload.keys).to include(key1, key2)
          expect(payload[key1]).to eq(key1: 'value1')
          expect(payload[key2]).to eq(key2: 'value2')
        end
      end

      describe '#application_payload' do
        it 'return empty payload when deployments are empty' do
          expect(@builder.send(:application_payload, environment)).to eq({})
        end

        it 'return merged payload that contains all deployments' do
          environment.status = :CREATE_COMPLETE
          application1 = FactoryGirl.create(:application, name: 'application1')
          application2 = FactoryGirl.create(:application, name: 'application2')
          history1 = FactoryGirl.create(:application_history, application: application1)
          history2 = FactoryGirl.create(:application_history, application: application2)

          FactoryGirl.create(:deployment, environment: environment, application_history: history1)
          FactoryGirl.create(:deployment, environment: environment, application_history: history2)
          environment.status = :PROGRESS

          key1 = 'cloudconductor/applications/application1'
          key2 = 'cloudconductor/applications/application2'
          payload = @builder.send(:application_payload, environment)
          expect(payload.keys).to eq([key1, key2])
          expect(payload[key1][:cloudconductor][:applications]['application1']).to be_is_a(Hash)
          expect(payload[key2][:cloudconductor][:applications]['application2']).to be_is_a(Hash)
        end
      end
    end
  end
end
