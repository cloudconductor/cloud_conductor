module CloudConductor
  class Terraform
    class Parent
      attr_accessor :modules
      attr_reader :output

      def initialize(cloud)
        @cloud = cloud
        @variables = %w(aws_access_key aws_secret_key aws_region ssh_key_file)
        @modules = []
      end

      def variables
        @variables + @modules.map(&:dynamic_variables).flatten.uniq
      end

      def collect_outputs(key)
        values = @modules.select { |m| m.outputs.include? key }.map do |m|
          "split(\", \", module.#{m.name}.#{key})"
        end

        "concat(#{values.join(', ')})"
      end

      def save(path)
        template = File.read(File.expand_path("../templates/#{@cloud.type}.tf.erb", __FILE__))
        File.write(path, ERB.new(template, nil, '-').result(binding))
      end

      def cleanup
        modules.each(&:cleanup)
      end
    end
  end
end
