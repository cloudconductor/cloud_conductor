require 'cloud_conductor/updaters/updater'

module CloudConductor
  module Updaters
    class Terraform < Updater
      def initialize(cloud, environment)
        @cloud = cloud
        @environment = environment
      end

      def update
      end
    end
  end
end
