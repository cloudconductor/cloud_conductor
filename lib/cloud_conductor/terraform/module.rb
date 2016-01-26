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
        template = load_templates("#{@source}/*.tf")

        @outputs = (template[:output] || {}).keys
        @variables = generate_variables(template, @mappings)
      end

      # Load dependencies from metadata.yml
      def load_metadata(path)
        metadata = YAML.load_file(path).symbolize_keys
        @dependencies = metadata[:dependencies] || []
      end

      # Load and combine templates
      def load_templates(directory)
        templates = Dir.glob(directory).map do |path|
          HCLParser.new.parse(File.read(path))
        end
        templates.inject(&:deep_merge).deep_symbolize_keys
      end

      def generate_variables(template, mappings)
        variables = {}
        (template[:variable] || {}).keys.each do |key|
          case
          when mappings[key].nil?
            variables[key] = "${var.#{key}}"
          when mappings[key][:type].to_sym == :static
            variables[key] = mappings[key][:value]
          when mappings[key][:type].to_sym == :module
            variables[key] = "${module.#{mappings[key][:value]}}"
          when mappings[key][:type].to_sym == :variable
            variables[key] = "${var.#{mappings[key][:value]}}"
          else
            fail "Unknown type(#{mappings[key][:type]})"
          end
        end
        variables
      end

      def dynamic_variables
        @variables.keys.select { |key| @mappings[key].nil? || @mappings[key][:type].to_sym == :variable }.map(&:to_s)
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
