require 'cloud_conductor/updaters/updater'

module CloudConductor
  module Updaters
    describe Updater do
      include_context 'default_resources'

      before do
        @updater = Updater.new(cloud, environment)
        allow(@updater).to receive(:get_nodes).and_return([])
      end

      describe '#new' do
        it 'keep @cloud' do
          expect(@updater.instance_variable_get(:@cloud)).to eq(cloud)
        end

        it 'keep @environment' do
          expect(@updater.instance_variable_get(:@environment)).to eq(environment)
        end
      end

      describe '#update' do
        before do
          allow(@updater).to receive(:update_infrastructure)
          allow(@updater).to receive(:send_events)
        end

        it 'keep @nodes that contains node list before update' do
          @updater.update
          expect(@updater.instance_variable_get(:@nodes)).to eq([])
        end

        it 'call subroutines that can override in child classes' do
          expect(@updater).to receive(:update_infrastructure)
          expect(@updater).to receive(:send_events)
          @updater.update
        end

        it 'update environment status to :CREATE_COMPLETE without error' do
          @updater.update
          expect(environment.status).to eq(:CREATE_COMPLETE)
        end

        it 'raise error and update environment status to :ERROR when some error has been occurred' do
          allow(@updater).to receive(:update_infrastructure).and_raise
          expect { @updater.update }.to raise_error(RuntimeError)
          expect(environment.status).to eq(:ERROR)
        end
      end

      describe '#update_infrastructure' do
        it 'raise exception when call don\'t overrided update_infrastructure' do
          allow(@updater).to receive(:update_infrastructure).and_call_original
          expect { @updater.send(:update_infrastructure) }.to raise_error(RuntimeError)
        end
      end

      describe '#send_events' do
        before do
          @event = double(:event, sync_fire: 1)
          allow(environment).to receive(:event).and_return(@event)

          @updater.instance_variable_set(:@nodes, [])
        end

        it 'will request configure event to consul' do
          expect(@event).to receive(:sync_fire).with(:configure)
          @updater.send(:send_events, environment)
        end

        it 'won\'t request restore event to consul when instance have not been added' do
          expect(@event).not_to receive(:sync_fire).with(:restore, anything, anything)
          @updater.send(:send_events, environment)
        end

        it 'will request restore event to added instances on consul' do
          @updater.instance_variable_set(:@nodes, %w(dummy1 dummy3))
          allow(@updater).to receive(:get_nodes).and_return(%w(dummy1 dummy2 dummy3))

          expect(@event).to receive(:sync_fire).with(:restore, {}, node: ['dummy2'])
          @updater.send(:send_events, environment)
        end

        it 'won\'t request deploy event to consul when instance have not been added' do
          expect(@event).not_to receive(:sync_fire).with(:deploy, anything, anything)
          @updater.send(:send_events, environment)
        end

        it 'won\'t request deploy event to consul when application have not been deployed' do
          @updater.instance_variable_set(:@nodes, %w(dummy1 dummy3))
          allow(@updater).to receive(:get_nodes).and_return(%w(dummy1 dummy2 dummy3))

          expect(@event).not_to receive(:sync_fire).with(:deploy, {}, node: ['dummy2'])
          @updater.send(:send_events, environment)
        end

        it 'will request deploy event to consul when create environment that already deploymented' do
          @updater.instance_variable_set(:@nodes, %w(dummy1 dummy3))
          allow(@updater).to receive(:get_nodes).and_return(%w(dummy1 dummy2 dummy3))

          environment.status = :CREATE_COMPLETE
          FactoryGirl.create(:deployment, environment: environment, application_history: application_history)

          expect(@event).to receive(:sync_fire).with(:deploy, {}, node: ['dummy2'])
          @updater.send(:send_events, environment)
        end

        it 'will request spec event to consul' do
          expect(@event).to receive(:sync_fire).with(:spec)
          @updater.send(:send_events, environment)
        end
      end
    end
  end
end
