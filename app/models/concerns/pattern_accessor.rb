require 'open3'
require 'ruby-hcl/lib/hcl'

module PatternAccessor
  def clone_repository(url, revision)
    fail 'PatternAccessor#clone_repository needs block' unless block_given?

    path = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}")

    _, _, status = Open3.capture3('git', 'clone', url, path)
    fail 'An error has occurred while git clone' unless status.success?

    Dir.chdir path do
      unless revision.blank?
        _, _, status = Open3.capture3('git', 'checkout', revision)
        fail 'An error has occurred while git checkout' unless status.success?
      end
    end

    yield path
  ensure
    FileUtils.rm_r path, force: true if path
  end

  private

  def load_template(path)
    template_path = File.expand_path('template.json', path)
    JSON.parse(File.open(template_path).read).with_indifferent_access
  rescue Errno::ENOENT
    {}
  end

  def load_metadata(path)
    metadata_path = File.expand_path('metadata.yml', path)
    YAML.load_file(metadata_path).with_indifferent_access
  rescue Errno::ENOENT
    raise 'metadata.yml is not contained in pattern'
  end

  def read_parameters(path)
    {
      'cloud_formation' => read_cloud_formation_parameters(path),
      'terraform' => read_terraform_parameters(path)
    }
  end

  def read_cloud_formation_parameters(path)
    load_template(path)['Parameters'] || {}
  end

  def read_terraform_parameters(path)
    results = {}
    Dir.glob("#{path}/templates/*") do |directory|
      cloud = directory.split('/').last
      hash = Dir.glob("#{directory}/*.tf").map { |path| HCLParser.new.parse(File.read(path)) }.inject(&:deep_merge)
      results[cloud] = hash['variable']
    end
    results
  end

  def read_roles(path)
    template = load_template(path)
    return [] if template[:Resources].nil?

    resources = {}
    resources.update template[:Resources].select(&type?('AWS::AutoScaling::LaunchConfiguration'))
    resources.update template[:Resources].select(&type?('AWS::EC2::Instance'))

    roles = resources.map do |key, resource|
      next key if resource[:Metadata].nil?
      next key if resource[:Metadata][:Role].nil?
      resource[:Metadata][:Role]
    end
    roles.uniq
  end

  def type?(type)
    ->(_, resource) { resource[:Type] == type }
  end
end
