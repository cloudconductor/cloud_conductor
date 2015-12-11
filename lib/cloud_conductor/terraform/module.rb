require 'ruby-hcl/lib/hcl'

module CloudConductor
  class Terraform
    class Module
      attr_reader :name, :cloud, :source, :dependencies, :variables, :outputs
      def initialize(cloud, snapshot, mappings)
        @cloud = cloud
        @name = snapshot.name
        @cloned_path = clone_repository(snapshot.url, snapshot.revision)
        @source = "#{@cloned_path}/templates/#{@cloud.type}"
        @mappings = mappings

        load_metadata("#{@cloned_path}/metadata.yml")
        load_templates("#{@source}/*.tf")
      end

      # Load dependencies from metadata.yml
      def load_metadata(path)
        metadata = YAML.load_file(path).symbolize_keys
        @dependencies = metadata[:dependencies] || []
      end

      # Load variables and outputs from templates
      def load_templates(directory)
        templates = Dir.glob(directory).map do |path|
          HCLParser.new.parse(File.read(path))
        end
        template = templates.inject(&:deep_merge).deep_symbolize_keys

        @outputs = (template[:output] || {}).keys

        @variables = {}
        (template[:variable] || {}).keys.each do |key|
          case
          when @mappings[key][:type].to_sym == :static
            @variables[key] = @mappings[key][:value]
          when @mappings[key][:type].to_sym == :module
            @variables[key] = "${module.#{@mappings[key][:value]}}"
          when @mappings[key][:type].to_sym == :variable
            @variables[key] = "${var.#{@mappings[key][:value]}}"
          else
            fail "Unknown type(#{@mappings[key][:type]})"
          end
        end
      end

      def dynamic_variables
        @variables.keys.select { |key| @mappings[key][:type] == :variable }
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
