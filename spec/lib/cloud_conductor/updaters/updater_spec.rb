require 'cloud_conductor/updaters/updater'

module CloudConductor
  module Updaters
    describe Updater do
      describe '#new' do
        it 'raise exception when instantiate abstract updater' do
          expect { Updater.new(nil, nil) }.to raise_error(RuntimeError)
        end
      end
    end
  end
end
