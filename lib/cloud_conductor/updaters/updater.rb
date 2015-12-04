module CloudConductor
  module Updaters
    class Updater
      def initialize(_cloud, _environment)
        fail "Can't instantiate abstract updater"
      end

      def update
        fail 'Unimplement method'
      end
    end
  end
end
