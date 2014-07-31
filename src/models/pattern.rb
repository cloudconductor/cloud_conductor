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
require 'open-uri'

class Pattern < ActiveRecord::Base
  has_many :patterns_clouds, dependent: :destroy
  has_many :clouds, through: :patterns_clouds
  has_many :images, dependent: :destroy

  validates :name, presence: true
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
end
