# -*- coding: utf-8 -*-
# Copyright 2014 TIS Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'sinatra/activerecord'
require 'yaml'

class Pattern < ActiveRecord::Base # rubocop:disable ClassLength
  before_save :execute_packer
  self.inheritance_column = nil

  has_many :patterns_clouds, dependent: :destroy
  has_many :clouds, through: :patterns_clouds
  has_many :images, dependent: :destroy

  validates :url, format: { with: URI.regexp }
  validates :clouds, presence: true

  validate do
    errors.add(:clouds, 'can\'t contain duplicate cloud in clouds attribute') unless clouds.size == clouds.uniq.size
  end

  after_initialize do
    self.protocol ||= 'git'
  end

  def status
    return :ERROR if images.any? { |image| image.status == :ERROR }
    return :PROGRESS if images.any? { |image| image.status == :PROGRESS }
    :CREATE_COMPLETE
  end

  def as_json(options = {})
    super options.merge(methods: :status, except: :parameters)
  end

  def type
    super && super.to_sym
  end

  def execute_packer
    clone_repository do |path|
      metadata = load_metadata path
      roles = load_roles path
      update_metadata path, metadata

      if CloudConductor::Config.consul.options.acl
        status, stdout, stderr = systemu('consul keygen')
        fail "consul keygen failed.\n#{stderr}" unless status.success?
        self.consul_secret_key = stdout.chomp
      else
        self.consul_secret_key = ''
      end

      operating_systems = OperatingSystem.candidates(metadata[:supports])
      roles.each do |role|
        create_images operating_systems, role, metadata[:name], consul_secret_key
      end
    end

    true
  end

  def clone_repository
    fail 'Pattern#clone_repository needs block' unless block_given?

    path = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}")

    fail 'An error has occurred while git clone' unless system("git clone #{url} #{path}")

    Dir.chdir path do
      unless revision.blank?
        fail 'An error has occurred while git checkout' unless system("git checkout #{revision}")
      end
    end

    yield path
  ensure
    FileUtils.rm_r path, force: true if path
  end

  def parameters(is_include_computed = false)
    return attributes['parameters'] if is_include_computed

    parameters = JSON.parse(attributes['parameters'] || '{}').reject do |_, parameter|
      parameter['Description'] =~ /^\[computed\]/
    end

    parameters.to_json
  end

  private

  def type?(type)
    ->(_, resource) { resource[:Type] == type }
  end

  def load_metadata(path)
    metadata_path = File.expand_path('metadata.yml', path)
    YAML.load_file(metadata_path).with_indifferent_access
  end

  def load_roles(path)
    template_path = File.expand_path('template.json', path)
    template = JSON.parse(File.open(template_path).read).with_indifferent_access

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

  def update_metadata(path, metadata)
    self.name = metadata[:name]
    self.description = metadata[:description]
    self.type = metadata[:type]
    self.parameters = load_parameters(path).to_json

    Dir.chdir path do
      self.revision = `git log --pretty=format:%H --max-count=1`
      fail 'An error has occurred whild git log' if $CHILD_STATUS && $CHILD_STATUS.exitstatus != 0
    end
  end

  def create_images(operating_systems, role, pattern_name, consul_secret_key) # rubocop:disable MethodLength
    clouds.each do |cloud|
      operating_systems.each do |operating_system|
        images.build(cloud: cloud, operating_system: operating_system, role: role)
      end
    end

    parameters = {
      repository_url: url,
      revision: revision,
      clouds: clouds.map(&:name),
      operating_systems: operating_systems.map(&:name),
      role: role,
      pattern_name: pattern_name,
      consul_secret_key: consul_secret_key
    }

    CloudConductor::PackerClient.new.build(parameters) do |results|
      results.each do |key, result|
        cloud_name, os_name = key.split(BaseImage::SPLITTER)
        cloud = Cloud.where(name: cloud_name).first
        operating_system = OperatingSystem.where(name: os_name).first
        image = images.where(cloud: cloud, operating_system: operating_system, role: role).first
        image.status = result[:status] == :SUCCESS ? :CREATE_COMPLETE : :ERROR
        image.image = result[:image]
        image.message = result[:message]
        image.save!
      end
    end
  end
end
