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

class Application < ActiveRecord::Base
  belongs_to :system
  has_many :histories, class_name: :ApplicationHistory, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :system, presence: true

  def latest
    histories.last
  end

  def latest_version
    histories.last.version
  end

  def to_json(options = {})
    super options.merge(methods: [:latest, :latest_version])
  end

  def dup
    application = super
    application.system = nil
    application
  end
end
