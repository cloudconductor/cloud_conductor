require 'cloud_conductor/builders/builder'

module CloudConductor
  module Builders
    describe Builder do
      describe '#new' do
        it 'raise exception when instantiate abstract builder' do
          expect { Builder.new(nil, nil) }.to raise_error(RuntimeError)
        end
      end
    end
  end
end
