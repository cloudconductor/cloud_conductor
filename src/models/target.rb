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

class Target < ActiveRecord::Base
  belongs_to :cloud
  belongs_to :operating_system

  ALLOW_RECEIVERS = %w(target cloud operating_system)

  def name
    "#{cloud.name}-#{operating_system.name}"
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

  def target
    self
  end
end
