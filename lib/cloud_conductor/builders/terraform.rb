require 'cloud_conductor/builders/builder'

module CloudConductor
  module Builders
    class Terraform < Builder
      def initialize(cloud, environment)
        @cloud = cloud
        @environment = environment
      end

      def build
      end
    end
  end
end
