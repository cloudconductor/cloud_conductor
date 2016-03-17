require 'cloud_conductor/terraform/module'

module CloudConductor
  class Terraform
    describe Module do
      before do
        @cloud = FactoryGirl.build(:cloud)
        @snapshot = FactoryGirl.build(:pattern_snapshot)
        @mappings = {}

        allow_any_instance_of(Module).to receive(:clone_repository)
        allow_any_instance_of(Module).to receive(:load_metadata)
        allow_any_instance_of(Module).to receive(:load_templates).and_return({})
        allow_any_instance_of(Module).to receive(:generate_variables)
        @module = Module.new(@cloud, @snapshot, @mappings)
      end

      describe '#initialize' do
        it 'will call subroutines' do
          expect_any_instance_of(Module).to receive(:clone_repository)
          Module.new(@cloud, @snapshot, @mappings)
        end
      end

      describe '#load_templates' do
        before do
          allow(@module).to receive(:load_templates).and_call_original

          allow(Dir).to receive(:glob)
          allow(File).to receive(:read)
        end

        it 'return merged hash when templates directory has two templates' do
          allow(Dir).to receive(:glob).with('dummy').and_return(['dummy1.tf', 'dummy2.tf'])

          hash1 = { key1: 'value1', key2: { child1: 'cvalue1' } }
          hash2 = { key3: 'value3', key2: { child2: 'cvalue2' } }
          allow(HCLParser).to receive_message_chain(:new, :parse).and_return(hash1, hash2)

          expected_hash = {
            key1: 'value1',
            key2: {
              child1: 'cvalue1',
              child2: 'cvalue2'
            },
            key3: 'value3'
          }
          expect(@module.load_templates('dummy')).to eq(expected_hash)
        end

        it 'return empty hash when templates directory does not found' do
          allow(Dir).to receive(:glob).with('dummy').and_return([])

          expect(@module.load_templates('dummy')).to eq({})
        end
      end
    end
  end
end
