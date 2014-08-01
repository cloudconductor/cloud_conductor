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
    return :pending if images.any? { |image| image.status == :pending }
    :created
  end

  before_save do
    temporary = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}", File.dirname(__FILE__))
    clone_command = "git clone #{uri} #{temporary}"
    fail 'An error has occurred while git clone' unless system(clone_command)

    unless revision.blank?
      checkout_command = "cd #{temporary}; git checkout #{revision}"
      fail 'An error has occurred while git checkout' unless system(checkout_command)
    end

    metadata_path = File.expand_path('metadata.yml', temporary)
    metadata = YAML.load_file(metadata_path).with_indifferent_access

    self.name = metadata[:name]
    self.description = metadata[:description]
    self.type = metadata[:type]

    branch = revision || ''
    self.revision = `cd #{temporary}; git log --pretty=format:%H --max-count=1 #{branch}`
    fail 'An error has occurred whild git log' if $CHILD_STATUS && $CHILD_STATUS.exitstatus != 0

    FileUtils.rm_r temporary, force: true
    true
  end
end
