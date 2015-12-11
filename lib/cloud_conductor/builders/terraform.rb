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
        directory = generate_template(@cloud, @environment, mappings)
        outputs = execute_terraform(directory)
        @environment.update_attribute(:ip_address, frontend_addresses(outputs))
      rescue => e
        reset
        raise e
      end

      def generate_template(cloud, environment, mappings)
        parent = CloudConductor::Terraform::Parent.new(cloud)
        environment.blueprint_history.pattern_snapshots.each do |snapshot|
          parent.modules << CloudConductor::Terraform::Module.new(cloud, snapshot, mappings[snapshot.name])
        end

        temporary = File.expand_path("../../tmp/terraform/#{SecureRandom.uuid}", File.dirname(__FILE__))
        FileUtils.mkdir_p temporary unless Dir.exist? temporary

        parent.save("#{temporary}/template.tf")
        parent.cleanup
        temporary
      end

      def execute_terraform(directory)
        options = {
          terraform_path: CloudConductor::Config.terraform.path
        }
        terraform = Rterraform::Client.new(directory, options)

        # terraform get
        terraform.get

        # terraform plan
        variables = {
          bootstrap_expect: 0
        }
        outputs = terraform.plan(variables)

        # terraform apply
        variables[:bootstrap_expect] = bootstrap_expect(outputs)
        terraform.apply(variables)
        terraform.output
      end

      def bootstrap_expect(outputs)
        instance_types = %w(aws_instance openstack_compute_instance_v2)
        outputs['module'].values.inject(0) do |sum, module_output|
          instance_types.inject(sum) do |sum, type|
            sum + (module_output[type] || {}).size
          end
        end
      end

      def frontend_addresses(outputs)
        outputs['module'].values.map { |value| value['frontend_addresses'] }.compact.join(', ')
      end
    end
  end
end
