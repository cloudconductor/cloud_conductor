require 'cloud_conductor/builders/builder'
require 'rterraform'

module CloudConductor
  module Builders
    class Terraform < Builder
      def initialize(cloud, environment)
        super
      end

      private

      def build_infrastructure(mappings = {})
      end
    end
  end
end
