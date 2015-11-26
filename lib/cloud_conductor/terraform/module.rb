module CloudConductor
  class Terraform
    class Module
      attr_accessor :name, :source, :dependencies, :variables, :outputs
      def initialize(pattern, cloud)
        @name = pattern.name
        @cloned_path = clone_repository(pattern.url, pattern.revision)
        @source = "#{@cloned_path}/templates/#{cloud.type}"

        # Load dependencies, variables and outputs from metadata.yml
        metadata = YAML.load_file("#{@cloned_path}/metadata.yml").symbolize_keys
        @variables = {}
        @outputs = {}

        @dependencies = metadata[:dependencies] | []
        metadata[:variables].map { |variable| @variables[variable] = nil }
        metadata[:outputs].map { |output| @outputs[output] = nil }
      end

      def resolve(modules)
        @variables.keys.each do |key|
          m = @dependencies.find { |m| modules[m].outputs.keys.include?(key) }
          if m.nil?
            @variables[key] = "var.#{key}"
          else
            @variables[key] = "module.#{m}.#{key}"
          end
        end
      end

      def cleanup
        FileUtils.rm_r @cloned_path
      end

      private

      def clone_repository(url, revision)
        path = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}")

        # FIXIT: Use -b option to checkout branch
        _, _, status = Open3.capture3('git', 'clone', url, path)
        fail 'An error has occurred while git clone' unless status.success?

        Dir.chdir path do
          unless revision.blank?
            _, _, status = Open3.capture3('git', 'checkout', revision)
            fail 'An error has occurred while git checkout' unless status.success?
          end
        end
        path
      end
    end
  end
end
