module CloudConductor
  module Builders
    class Builder
      def initialize(_cloud, _environment)
        fail "Can't instantiate abstract builder"
      end

      def build
        fail 'Unimplement method'
      end
    end
  end
end
