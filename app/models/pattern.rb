require 'open3'

class Pattern < ActiveRecord::Base # rubocop:disable ClassLength
  self.inheritance_column = nil

  belongs_to :blueprint, inverse_of: :patterns
  has_many :images, dependent: :destroy
  has_many :stacks

  validates :url, format: { with: URI.regexp }
  validates_presence_of :blueprint

  after_initialize do
    self.protocol ||= 'git'
  end

  before_save :execute_packer, if: -> { url_changed? || revision_changed? }

  def status
    if images.empty? || images.any? { |image| image.status == :ERROR }
      :ERROR
    elsif images.all? { |image| image.status == :CREATE_COMPLETE }
      :CREATE_COMPLETE
    else
      :PROGRESS
    end
  end

  def as_json(options = {})
    super({ methods: :status, except: :parameters }.merge(options))
  end

  def clone_repository
    fail 'Pattern#clone_repository needs block' unless block_given?

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

  def filtered_parameters(is_include_computed = false)
    return JSON.parse(parameters) if is_include_computed
    filtered_parameters = JSON.parse(parameters || '{}').reject do |_, param|
      param['Description'] =~ /^\[computed\]/
    end
    filtered_parameters
  end

  def set_metadata_from_repository
    clone_repository do |path|
      metadata = load_metadata path
      update_metadata path, metadata

      @roles = collect_roles(load_template(path))
    end
  end

  private

  def execute_packer
    set_metadata_from_repository unless name

    @roles.each { |role| create_images(role) }

    true
  rescue Errno::ENOENT => e
    Log.error 'Pattern does not have metadata.yml or template.json'
    Log.debug e
  end

  def type?(type)
    ->(_, resource) { resource[:Type] == type }
  end

  def load_template(path)
    template_path = File.expand_path('template.json', path)
    JSON.parse(File.open(template_path).read).with_indifferent_access
  end

  def load_metadata(path)
    metadata_path = File.expand_path('metadata.yml', path)
    YAML.load_file(metadata_path).with_indifferent_access
  end

  def collect_roles(template)
    fail 'Resources was not found' if template[:Resources].nil?

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

  def load_parameters(path)
    template_path = File.expand_path('template.json', path)
    template = JSON.parse(File.open(template_path).read)
    template['Parameters'] || {}
  end

  def load_backup_config(path)
    YAML.load_file(File.expand_path('config/backup_restore.yml', path))
  rescue
    {}
  end

  def update_metadata(path, metadata)
    self.name = metadata[:name]
    self.type = metadata[:type]
    self.parameters = load_parameters(path).to_json
    self.backup_config = load_backup_config(path).to_json

    Dir.chdir path do
      self.revision = `git log --pretty=format:%H --max-count=1`
      fail 'An error has occurred whild git log' if $CHILD_STATUS && $CHILD_STATUS.exitstatus != 0
    end
  end

  def create_images(role)
    new_images = blueprint.project.base_images('CentOS-6.5').map do |base_image|
      images.build(cloud: base_image.cloud, base_image: base_image, role: role)
    end
    packer_variables = {
      pattern_name: name,
      patterns: {},
      role: role,
      consul_secret_key: blueprint.consul_secret_key
    }

    blueprint.patterns.each do |pattern|
      packer_variables[:patterns][pattern.name] = {
        url: pattern.url,
        revision: pattern.revision
      }
    end

    packer_client = CloudConductor::PackerClient.new
    packer_client.build(new_images, packer_variables) do |results|
      update_images(results)
    end
  end

  def update_images(results)
    ActiveRecord::Base.connection_pool.with_connection do
      results.each do |name, result|
        image = images.where(name: name).first
        image.status = result[:status] == :SUCCESS ? :CREATE_COMPLETE : :ERROR
        image.image = result[:image]
        image.message = result[:message]
        image.save!
      end
    end
  end
end
