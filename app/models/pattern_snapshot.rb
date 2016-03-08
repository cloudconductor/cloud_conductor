class PatternSnapshot < ActiveRecord::Base
  include PatternAccessor
  self.inheritance_column = nil

  belongs_to :blueprint_history
  has_many :images, dependent: :destroy
  has_many :stacks

  validates_presence_of :blueprint_history

  before_destroy :check_pattern_usage

  def status
    if images.any? { |image| image.status == :ERROR }
      :ERROR
    elsif images.all? { |image| image.status == :CREATE_COMPLETE }
      :CREATE_COMPLETE
    else
      :PROGRESS
    end
  end

  def as_json(options = {})
    super({ except: :parameters, methods: :status }.merge(options))
  end

  # rubocop:disable CyclomaticComplexity, PerceivedComplexity
  def filtered_parameters(is_include_computed = false, clouds = nil, providers = nil)
    filtered_parameters = JSON.parse(parameters || '{}')

    # Reject unused cloud
    (filtered_parameters['terraform'] || {}).slice!(*clouds) if clouds

    # Reject unused provider
    filtered_parameters.slice!(*providers) if providers

    # Reject computed parameter
    return filtered_parameters if is_include_computed
    (filtered_parameters['cloud_formation'] || {}).reject!(&computed?)
    (filtered_parameters['terraform'] || {}).each do |_, variables|
      variables.reject!(&computed?)
    end
    filtered_parameters
  end
  # rubocop:enable CyclomaticComplexity, PerceivedComplexity

  def computed?
    ->(_, v) { (v['Description'] || v['description']) =~ /^\[computed\]/ }
  end

  def freeze_pattern(path)
    metadata = load_metadata(path)

    self.name = metadata[:name]
    self.type = metadata[:type]
    self.providers = metadata[:providers].to_json if metadata[:providers]
    self.parameters = read_parameters(path).to_json
    self.roles = (metadata[:roles] || []).to_json
    freeze_revision(path)
  end

  def create_images(archived_path, &block)
    JSON.parse(roles).each do |role|
      base_images = blueprint_history.blueprint.project.clouds.map do |cloud|
        result = BaseImage.filtered_base_image(cloud, platform, platform_version)
        fail 'BaseImage does not exist' if result.nil?
        result
      end

      new_images = base_images.map do |base_image|
        images.build(cloud: base_image.cloud, base_image: base_image, role: role)
      end
      packer_variables = {
        pattern_name: name,
        role: role,
        consul_secret_key: blueprint_history.consul_secret_key,
        ssh_public_key: blueprint_history.ssh_public_key,
        archived_path: archived_path
      }

      CloudConductor::PackerClient.new.build(new_images, packer_variables, block)
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

  private

  def freeze_revision(path)
    Dir.chdir path do
      self.revision = `git log --pretty=format:%H --max-count=1`
      fail 'An error has occurred whild git log' if $CHILD_STATUS && $CHILD_STATUS.exitstatus != 0
    end
  end

  def check_pattern_usage
    fail 'Some stacks use this pattern' unless stacks.empty?
  end
end
