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

class OperatingSystem < ActiveRecord::Base
  validates :name, presence: true, format: /\A[^\-]+\Z/

  def self.candidates(supports)
    (supports || []).map do |support|
      fail "version supports only '= 1.2' format currently" unless support[:version] =~ /^=\s*([\d.]+)$/
      name = support[:os]
      version = Regexp.last_match[1]
      OperatingSystem.where(name: name, version: version)
    end.flatten
  end
end