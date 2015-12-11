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
          cloud = @builder.instance_variable_get :@cloud
          expect(cloud).to eq(cloud)
        end

        it 'keep @environment' do
          env = @builder.instance_variable_get :@environment
          expect(env).to eq(environment)
        end
      end

      describe '#build' do
        before do
          allow(@builder).to receive(:build_infrastructure)
        end

        it 'call subroutines that can override in child classes' do
          expect(@builder).to receive(:build_infrastructure)
          @builder.build
        end
      end

      describe '#build_infrastructure' do
        it 'raise exception when call don\'t overrided build_infrastructure' do
          allow(@builder).to receive(:build_infrastructure).and_call_original
          expect { @builder.send(:build_infrastructure) }.to raise_error(RuntimeError)
        end
      end
    end
  end
end
