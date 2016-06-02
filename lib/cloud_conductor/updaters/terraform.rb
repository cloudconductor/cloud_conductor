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
          mapping = merge_default_mapping(cloud, mappings[snapshot.name])
          parent.modules << CloudConductor::Terraform::Module.new(cloud, snapshot, mapping)
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

        # terraform show
        current_resources = terraform.show

        variables[:bootstrap_expect] = 0
        destroy_rules(terraform, variables, current_resources) if @cloud.type == 'aws'

        # terraform plan
        resources = terraform.plan(variables, 'module-depth' => 1)

        # terraform apply
        current_instance = bootstrap_expect(current_resources)
        add_instance = bootstrap_expect(resources[:add])
        destroy_instance = bootstrap_expect(resources[:destroy])
        variables[:bootstrap_expect] = current_instance + add_instance - destroy_instance
        terraform.apply(variables)
        terraform.output
      end

      def destroy_rules(terraform, variables, resources)
        rules = resources['module'].map do |pattern_name, resources|
          (resources['aws_security_group_rule'] || {}).keys.map do |name|
            "module.#{pattern_name}.aws_security_group_rule.#{name}"
          end
        end.flatten

        terraform.destroy(variables, target: rules)
      end

      def bootstrap_expect(resources)
        instance_types = %w(aws_instance openstack_compute_instance_v2 wakamevdc_instance)
        (resources['module'] || {}).values.inject(0) do |sum, module_resources|
          sum + instance_types.inject(0) do |sum, type|
            sum + (module_resources[type] || {}).inject(0) do |sum, (_, instance_resources)|
              next sum + 1 if instance_resources == {}
              sum + instance_resources.keys.count { |key| key =~ /^\d+$/ }
            end
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
        date = @environment.created_at.localtime.strftime('%Y%m%d%H%M%S')
        File.expand_path("../../../tmp/terraform/environment#{@environment.id}_#{date}_#{@cloud.name}", File.dirname(__FILE__))
      end

      def terraform_variables(ssh_key_file = '')
        variables = {}
        variables.merge!(cloud_variables(@cloud, @environment))
        variables.merge!(image_variables(@cloud, @environment))
        variables[:ssh_key_file] = ssh_key_file
        variables
      end

      def cloud_variables(cloud, environment) # rubocop:disable MethodLength
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
            os_tenant_name: cloud.tenant_name,
            environment_id: environment.id
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
        target_images = images.select { |image| image.cloud == cloud }

        results = {}
        target_images.each do |image|
          combined_roles = image.role.split(/\s*,\s*/).join('_')
          results["#{combined_roles}_image".to_sym] = image.image
        end
        results[:ssh_username] = target_images.first.base_image.ssh_username unless target_images.empty?
        results
      end

      def merge_default_mapping(cloud, mapping)
        return mapping unless cloud.type == 'openstack'

        return mapping unless mapping && mapping[:gateway_id]
        return mapping unless mapping[:gateway_id][:type] == 'static' && mapping[:gateway_id][:value] == 'auto'

        mapping[:gateway_id][:value] = default_gateway(cloud).id
        mapping
      end

      def default_gateway(cloud)
        neutron = ::Fog::Network.new(
          provider: :OpenStack,
          openstack_auth_url: cloud.entry_point + 'v2.0/tokens',
          openstack_api_key: cloud.secret,
          openstack_username: cloud.key,
          openstack_tenant: cloud.tenant_name
        )

        network = neutron.networks.find(&:router_external)
        fail "#{cloud.name} doesn't have external network" unless network
        network
      end
    end
  end
end
