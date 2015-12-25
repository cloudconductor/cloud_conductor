require 'cloud_conductor/builders/builder'
require 'rterraform'

module CloudConductor
  module Builders
    class Terraform < Builder
      def initialize(cloud, environment)
        super
      end

      private

      def build_infrastructure
        directory = generate_template(@cloud, @environment)
        variables = cloud_variables(@cloud)
        # TODO: Generate and put key on image when it had created by packer and store key to database
        variables[:ssh_key_file] = '~/.ssh/develop-key.pem'
        outputs = execute_terraform(directory, variables)
        @environment.update_attribute(:ip_address, frontend_addresses(outputs))
      rescue => e
        reset
        raise e
      end

      def generate_template(cloud, environment)
        mappings = JSON.parse(environment.mappings_json).with_indifferent_access
        parent = CloudConductor::Terraform::Parent.new(cloud)
        environment.blueprint_history.pattern_snapshots.each do |snapshot|
          parent.modules << CloudConductor::Terraform::Module.new(cloud, snapshot, mappings[snapshot.name])
        end

        temporary = File.expand_path("../../../tmp/terraform/#{SecureRandom.uuid}", File.dirname(__FILE__))
        FileUtils.mkdir_p temporary unless Dir.exist? temporary

        parent.save("#{temporary}/template.tf")
        temporary
      end

      def execute_terraform(directory, variables)
        options = {
          terraform_path: CloudConductor::Config.terraform.path
        }
        terraform = Rterraform::Client.new(directory, options)

        # terraform get
        terraform.get

        # terraform plan
        variables[:bootstrap_expect] = 0
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

      def cloud_variables(cloud)
        case cloud.type
        when 'aws'
          {
            aws_access_key: cloud.key,
            aws_secret_key: cloud.secret,
            aws_region: cloud.entry_point
          }
        when 'openstack'
          {
            openstack_user_name: cloud.key,
            openstack_password: cloud.secret,
            openstack_auth_url: cloud.entry_point + 'v2.0',
            openstack_tenant_name: cloud.tenant_name
          }
        else
          {}
        end
      end
    end
  end
end
