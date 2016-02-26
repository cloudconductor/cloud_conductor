class BlueprintHistory < ActiveRecord::Base
  include PatternAccessor
  include Encryptor
  belongs_to :blueprint
  has_many :pattern_snapshots, dependent: :destroy

  validates_presence_of :blueprint

  before_create :set_consul_secret_key
  before_create :set_ssh_private_key
  before_create :set_version
  before_create :build_pattern_snapshots

  def project
    blueprint.project
  end

  def status
    if pattern_snapshots.any? { |pattern_snapshot| pattern_snapshot.status == :ERROR }
      :ERROR
    elsif pattern_snapshots.all? { |pattern_snapshot| pattern_snapshot.status == :CREATE_COMPLETE }
      :CREATE_COMPLETE
    else
      :PROGRESS
    end
  end

  def providers
    return {} if pattern_snapshots.empty?

    result = {}
    providers = pattern_snapshots.map(&:providers).compact.map do |provider|
      JSON.parse(provider)
    end

    (providers.map(&:keys).inject(&:|) || []).each do |cloud|
      providers.each do |provider|
        list = [provider[cloud]].flatten.compact
        result[cloud] ||= list
        result[cloud] = result[cloud] & list
      end
    end

    result.reject! { |_key, value| value.empty? }

    order = CloudConductor::Config.system_build.providers
    result.each do |_key, value|
      value.sort! do |a, b|
        (order.index(a.to_sym) || order.size) <=> (order.index(b.to_sym) || order.size)
      end
    end
  end

  def ssh_private_key
    crypt.decrypt_and_verify(encrypted_ssh_private_key) if encrypted_ssh_private_key
  end

  def ssh_private_key=(s)
    self.encrypted_ssh_private_key = crypt.encrypt_and_sign(s)
  end

  def ssh_public_key
    return nil if ssh_private_key.nil?
    Base64.encode64(OpenSSL::PKey::RSA.new(ssh_private_key).public_key.to_blob).gsub(/[\r\n]/, '')
  end

  def as_json(options = {})
    json = super({ methods: :status }.merge(options))
    json['encrypted_ssh_private_key'] = '********'
    json
  end

  private

  def set_consul_secret_key
    return unless CloudConductor::Config.consul.options.acl
    self.consul_secret_key ||= SecureRandom.base64(16)
  end

  def set_ssh_private_key
    self.ssh_private_key = OpenSSL::PKey::RSA.generate(2048).to_pem
  end

  def set_version
    latest = blueprint.histories.last
    self.version = 1
    self.version = latest.version + 1 if latest
  end

  def build_pattern_snapshots
    BlueprintPattern.eager_load(:pattern).where(blueprint_id: blueprint.id).each do |relation|
      pattern_snapshots.build(
        url: relation.pattern.url,
        revision: relation.revision || relation.pattern.revision,
        platform: relation.platform,
        platform_version: relation.platform_version,
        secret_key: relation.pattern.secret_key)
    end

    archives_directory = File.expand_path('./tmp/archives/')
    patterns_directory = File.join(archives_directory, SecureRandom.uuid)
    clone_repositories(pattern_snapshots, patterns_directory) do |snapshots|
      archived_path = compress_patterns(patterns_directory, archives_directory)
      snapshots.each do |snapshot|
        snapshot.create_images(archived_path) do |results|
          snapshot.update_images(results)
          FileUtils.rm_r archived_path if snapshot.status != :PROGRESS
        end
      end
    end

    fail 'Patterns don\'t have usable providers on any cloud' if providers.empty?
  end

  private

  def compress_patterns(source_directory, dest_directory)
    FileUtils.mkdir_p(dest_directory) unless Dir.exist?(dest_directory)
    archived_path = File.join(dest_directory, "#{SecureRandom.uuid}.tar")

    file_names = Dir.glob("#{source_directory}/*").map(&File.method(:basename))
    Open3.capture3('tar', '-zcvf', archived_path, '-C', source_directory, *file_names)
    archived_path
  end
end
