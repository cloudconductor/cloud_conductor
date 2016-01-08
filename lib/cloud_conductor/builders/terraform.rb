require 'rterraform'

module CloudConductor
  module Builders
    class Terraform < CloudConductor::Builders::Builder
      def initialize(cloud, environment)
        super
      end

      private

      def build_infrastructure
        @environment.stacks.each { |stack| stack.update_attributes(cloud: @cloud, status: :PROGRESS) }

        generate_template(@cloud, @environment)

        outputs = execute_terraform(terraform_variables)

        @environment.stacks.each { |stack| stack.update_attribute(:status, :CREATE_COMPLETE) }
        @environment.update_attribute(:ip_address, frontend_addresses(outputs))
      rescue => e
        @environment.stacks.each { |stack| stack.update_attribute(:status, :ERROR) }
        reset
        raise e
      end

      def generate_template(cloud, environment)
        mappings = JSON.parse(environment.mappings_json).with_indifferent_access
        parent = CloudConductor::Terraform::Parent.new(cloud)
        environment.blueprint_history.pattern_snapshots.each do |snapshot|
          parent.modules << CloudConductor::Terraform::Module.new(cloud, snapshot, mappings[snapshot.name])
        end

        FileUtils.mkdir_p template_directory unless Dir.exist? template_directory

        parent.save("#{template_directory}/template.tf")
      end

      def execute_terraform(variables)
        options = {
          terraform_path: CloudConductor::Config.terraform.path
        }
        terraform = Rterraform::Client.new(template_directory, options)

        # terraform get
        terraform.get

        # terraform plan
        variables[:bootstrap_expect] = 0
        outputs = terraform.plan(variables, 'module-depth' => 1)

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
        outputs.select { |k, _v| k.end_with? '.frontend_addresses' }.values.reject(&:blank?).join(', ')
      end

      def template_directory
        File.expand_path("../../../tmp/terraform/#{@environment.name}_#{@cloud.name}", File.dirname(__FILE__))
      end

      def terraform_variables
        variables = {}
        variables.merge!(cloud_variables(@cloud))
        variables.merge!(image_variables(@cloud, @environment))

        # TODO: Generate and put key on image when it had created by packer and store key to database
        variables[:ssh_key_file] = '~/.ssh/develop-key.pem'
        variables
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

      def image_variables(cloud, environment)
        images = environment.blueprint_history.pattern_snapshots.map(&:images).flatten
        results = {}
        images.select { |image| image.cloud == cloud }.each do |image|
          combined_roles = image.role.split(/\s*,\s*/).join('_')
          results["#{combined_roles}_image".to_sym] = image.image
        end
        results
      end

      def reset
      end
    end
  end
end
