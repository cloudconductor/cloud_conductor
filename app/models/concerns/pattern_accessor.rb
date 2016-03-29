require 'open3'
require 'ruby-hcl/lib/hcl'

module PatternAccessor
  def clone_repository(url, revision, options = {})
    secret_key = options[:secret_key]
    directory = options[:directory] || File.expand_path('./tmp/patterns/')
    cloned_path = File.join(directory, SecureRandom.uuid)

    if secret_key.blank?
      _, _, status = Open3.capture3('git', 'clone', url, cloned_path)
    else
      _, _, status = clone_private_repository(secret_key, url, cloned_path)
    end
    fail 'An error has occurred while git clone' unless status.success?

    checkout_revision(cloned_path, revision)

    yield cloned_path if block_given?
    cloned_path
  ensure
    FileUtils.rm_r cloned_path, force: true if block_given?
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

  def type?(type)
    ->(_, resource) { resource[:Type] == type }
  end

  def clone_private_repository(secret_key, url, clone_path)
    git_ssh_path = File.expand_path("./tmp/git_ssh/#{SecureRandom.uuid}")
    FileUtils.mkdir_p(git_ssh_path)
    File.open("#{git_ssh_path}/secret_key_file", 'w', 0600) { |f| f.puts secret_key }

    ssh_command = "exec ssh -oIdentityFile=#{git_ssh_path}/secret_key_file \"$@\""
    File.open("#{git_ssh_path}/git-ssh.sh", 'w', 0700) { |f| f.puts ssh_command }

    env = { 'GIT_SSH' => "#{git_ssh_path}/git-ssh.sh" }
    Open3.capture3(env, 'git', 'clone', "#{url}", "#{clone_path}")
  ensure
    FileUtils.rm_r git_ssh_path, force: true if git_ssh_path
  end

  def checkout_revision(path, revision)
    Dir.chdir path do
      unless revision.blank?
        _, _, status = Open3.capture3('git', 'checkout', revision)
        fail 'An error has occurred while git checkout' unless status.success?
      end
    end
  end

  def clone_repositories(snapshots, directory)
    fail 'PatternAccessor#cloen_repositories needs block' unless block_given?
    FileUtils.mkdir_p(directory) unless Dir.exist?(directory)
    snapshots.each do |snapshot|
      options = { secret_key: snapshot.secret_key, directory: directory }
      cloned_path = clone_repository(snapshot.url, snapshot.revision, options)
      snapshot.freeze_pattern(cloned_path)
      renamed_path = File.join(directory, snapshot.name)
      File.rename(cloned_path, renamed_path)
    end
    yield snapshots
  ensure
    FileUtils.rm_r directory, force: true
  end

  def compress_patterns(source_directory, dest_directory)
    FileUtils.mkdir_p(dest_directory) unless Dir.exist?(dest_directory)
    archived_path = File.join(dest_directory, "#{SecureRandom.uuid}.tar")

    file_names = Dir.glob("#{source_directory}/*").map(&File.method(:basename))
    Open3.capture3('tar', '-zcvf', archived_path, '-C', source_directory, *file_names)
    archived_path
  end
end
