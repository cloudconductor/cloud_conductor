require 'cloud_conductor/updaters/updater'

module CloudConductor
  module Updaters
    class Terraform < Updater
      def initialize(cloud, environment)
        super
      end

      private

      def update_infrastructure
        @environment.stacks.each { |stack| stack.update_attributes(cloud: @cloud, status: :PROGRESS) }

        generate_template(@cloud, @environment)

        outputs = save_ssh_private_key(@environment.blueprint_history.ssh_private_key) do |path|
          execute_terraform(terraform_variables(path))
        end

        @environment.stacks.each { |stack| stack.update_attribute(:status, :CREATE_COMPLETE) }
        @environment.update_attribute(:frontend_address, frontend_address(outputs))
        @environment.update_attribute(:consul_addresses, consul_addresses(outputs))
      rescue => e
        @environment.stacks.each { |stack| stack.update_attribute(:status, :ERROR) }
        reset
        raise e
      end

      def reset
      end

      def generate_template(cloud, environment)
        mappings = JSON.parse(environment.template_parameters).each_with_object({}) do |(k, v), h|
          h[k] = (v.with_indifferent_access[:terraform] || {})[cloud.type]
        end
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
        terraform = RubyTerraform::Client.new(template_directory, options)

        # terraform get
        terraform.get({}, update: true)

        # terraform plan
        variables[:bootstrap_expect] = 0
        outputs = terraform.plan(variables, 'module-depth' => 1)

        # terraform apply
        variables[:bootstrap_expect] = bootstrap_expect(outputs)
        terraform.apply(variables)
        terraform.output
      end

      def bootstrap_expect(outputs)
        instance_types = %w(aws_instance openstack_compute_instance_v2 wakamevdc_instance)
        outputs['module'].values.inject(0) do |sum, module_output|
          instance_types.inject(sum) do |sum, type|
            sum + (module_output[type] || {}).size
          end
        end
      end

      def frontend_address(outputs)
        frontend_addresses = outputs.select { |k, _v| k.end_with? '.frontend_address' }.values.reject(&:blank?)
        fail 'frontend_address output has multiple addresses' if frontend_addresses.size > 1
        frontend_addresses.first
      end

      def consul_addresses(outputs)
        outputs.select { |k, _v| k.end_with? '.consul_addresses' }.values.reject(&:blank?).join(', ')
      end

      def save_ssh_private_key(ssh_private_key)
        path = File.expand_path("./tmp/terraform/#{SecureRandom.uuid}.pem")
        File.open(path, 'w', 0400) do |file|
          file.write(ssh_private_key)
        end

        yield(path)
      ensure
        FileUtils.rm(path) if File.exist?(path)
      end

      def template_directory
        File.expand_path("../../../tmp/terraform/#{@environment.name}_#{@cloud.name}", File.dirname(__FILE__))
      end

      def terraform_variables(ssh_key_file = '')
        variables = {}
        variables.merge!(cloud_variables(@cloud))
        variables.merge!(image_variables(@cloud, @environment))
        variables[:ssh_key_file] = ssh_key_file
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
            os_user_name: cloud.key,
            os_password: cloud.secret,
            os_auth_url: cloud.entry_point + 'v2.0',
            os_tenant_name: cloud.tenant_name
          }
        when 'wakame-vdc'
          {
            api_endpoint: cloud.entry_point
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
    end
  end
end
