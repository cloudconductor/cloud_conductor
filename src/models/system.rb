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

class System < ActiveRecord::Base
  validates :name, presence: true
  validates :template_url, format: { with: URI.regexp }, allow_blank: true

  validate do
    if template_body.blank? && template_url.blank?
      errors.add(:template_body, ' or template_url must be required')
    end
    if !template_body.blank? && !template_url.blank?
      errors.add(:template_body, 'can\'t set with template_url')
    end
  end

  validates_each :template_body, :parameters do |record, attr, value|
    begin
      JSON.parse(value) unless value.nil?
    rescue JSON::ParserError
      record.errors.add(attr, 'is malformed or invalid json string')
    end
  end
end
