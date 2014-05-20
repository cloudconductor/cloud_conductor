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

class Cloud < ActiveRecord::Base
  validates :name, presence: true
  validates :entry_point, presence: true
  validates :key, presence: true
  validates :secret, presence: true
  validate do
    if cloud_type != 'aws' && cloud_type != 'openstack'
      errors.add(:cloud_type, ' must be "aws" or "openstack"')
    end
    if cloud_type == 'openstack' && tenant_id.blank?
      errors.add(:tenant_id, 'must not be blank in case that cloud_type is "openstack".')
    end
  end
end
