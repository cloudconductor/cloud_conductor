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

class Pattern < ActiveRecord::Base
  self.inheritance_column = nil

  has_many :patterns_clouds, dependent: :destroy
  has_many :clouds, through: :patterns_clouds
  has_many :images, dependent: :destroy

  validates :uri, format: { with: URI.regexp }
  validates :clouds, presence: true

  validate do
    errors.add(:clouds, 'can\'t contain duplicate cloud in clouds attribute') unless clouds.size == clouds.uniq.size
  end

  def status
    return :error if images.any? { |image| image.status == :error }
    return :processing if images.any? { |image| image.status == :processing }
    :created
  end

  def to_json(options = {})
    super options.merge(methods: :status)
  end

  before_save do
    path = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}")

    clone_repository path

    metadata = load_metadata path
    roles = load_roles path
    update_attributes metadata

    roles.each do |role|
      create_images metadata[:supports], role
    end

    remove_repository path

    true
  end

  private

  def type?(type)
    ->(_, resource) { resource[:Type] == type }
  end

  def clone_repository(path)
    clone_command = "git clone #{uri} #{path}"
    fail 'An error has occurred while git clone' unless system(clone_command)

    @root_directory = Dir.pwd
    Dir.chdir path

    return if revision.blank?

    checkout_command = "git checkout #{revision}"
    fail 'An error has occurred while git checkout' unless system(checkout_command)
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

  def update_attributes(metadata)
    self.name = metadata[:name]
    self.description = metadata[:description]
    self.type = metadata[:type]

    self.revision = `git log --pretty=format:%H --max-count=1`
    fail 'An error has occurred whild git log' if $CHILD_STATUS && $CHILD_STATUS.exitstatus != 0
  end

  def create_images(oss, role)
    clouds.each do |cloud|
      oss.each do |os|
        images.build(cloud: cloud, os: os, role: role)
      end
    end

    CloudConductor::PackerClient.new.build uri, revision, clouds.map(&:name), oss, role do |results|
      results.each do |key, result|
        cloud_name, os = key.split('-')
        cloud = Cloud.where(name: cloud_name).first
        image = Image.where(cloud: cloud, os: os, role: role).first
        image.status = result[:status] == :success ? :created : :error
        image.image = result[:image]
        image.message = result[:message]
        image.save!
      end
    end
  end

  def remove_repository(path)
    Dir.chdir @root_directory
    FileUtils.rm_r path, force: true
  end
end
