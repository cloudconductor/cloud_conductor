module CloudConductor
  class Terraform
    class Parent
      attr_accessor :variables, :outputs, :modules

      def initialize
        @variables = %w(aws_access_key aws_secret_key aws_region ssh_key_file)
        @outputs = {}
        @modules = {}
      end

      def resolve_dependencies
        @modules.each { |_, m| m.resolve(@modules) }
        @variables = (@variables + @modules.map { |_, m| m.variables.reject(&module_variable?).keys }).flatten.uniq
        @modules.each do |name, m|
          m.outputs.keys.each do |key|
            @outputs["#{name}.#{key}"] = "module.#{name}.#{key}"
          end
        end
      end

      def save(path)
        File.write('./tmp/main.tf', ERB.new(File.read('./main.tf.erb'), nil, '-').result(binding))
      end

      def cleanup
        modules.each do |_, m|
          m.cleanup
        end
      end

      def collect_outputs(key)
        cluster_addresses = @modules.select { |_, m| m.outputs.include? key }.each do |name, _|
          "split(\", \", module.#{name}.#{key})"
        end

        "concat(#{cluster_addresses.join(', ')})"
      end

      private

      def module_variable?
        -> (_, value) { value =~ /^module\./ }
      end
    end
  end
end
