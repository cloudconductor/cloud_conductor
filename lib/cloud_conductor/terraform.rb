require 'cloud_conductor/terraform/parent'
require 'cloud_conductor/terraform/module'

module CloudConductor
  class Terraform
    def initialize(directory)
    end

    def plan(variables = {}, options = {})
    end

    def apply(variables = {}, options = {})
    end

    def destroy(variables = {}, options = {})
    end
  end
end
