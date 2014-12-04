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

class BaseImage < ActiveRecord::Base
  belongs_to :cloud
  belongs_to :operating_system

  validates :operating_system, presence: true
  validates :source_image, presence: true
  validates :ssh_username, presence: true

  cattr_accessor :images

  SPLITTER = '----'
  SSH_USERNAME = 'ec2-user'
  ALLOW_RECEIVERS = %w(base_image cloud operating_system)
  IMAGES_FILE_PATH = File.expand_path('../../config/images.yml', File.dirname(__FILE__))

  after_initialize do
    self.operating_system ||= OperatingSystem.first
    self.ssh_username ||= SSH_USERNAME

    BaseImage.images ||= YAML.load_file(IMAGES_FILE_PATH)
    if cloud && cloud.type == :aws && source_image.nil?
      self.source_image = BaseImage.images[cloud.entry_point]
    end
  end

  def name
    "#{cloud.name}#{SPLITTER}#{operating_system.name}"
  end

  def to_json
    template = cloud.template
    template.gsub(/\{\{(\w+)\s*`(\w+)`\}\}/) do
      receiver_name = Regexp.last_match[1]
      method_name = Regexp.last_match[2]
      next Regexp.last_match[0] unless ALLOW_RECEIVERS.include? receiver_name
      send(receiver_name).send(method_name)
    end
  end

  def base_image
    self
  end
end
