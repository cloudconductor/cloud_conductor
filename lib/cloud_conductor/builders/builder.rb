module CloudConductor
  module Builders
    class Builder
      def initialize(cloud, environment)
        @cloud = cloud
        @environment = environment
      end

      def build
        build_infrastructure
      end

      private

      def build_infrastructure
        fail 'Unimplement method'
      end
    end
  end
end
