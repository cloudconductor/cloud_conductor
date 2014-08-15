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
  self.inheritance_column = nil

  has_many :targets, dependent: :destroy
  has_many :operating_systems, through: :targets

  before_destroy :raise_error_in_use

  validates :name, presence: true, format: /\A[^\-]+\Z/
  validates :entry_point, presence: true
  validates :key, presence: true
  validates :secret, presence: true
  validate do
    unless %i(aws openstack dummy).include? type
      errors.add(:type, ' must be "aws", "openstack" or "dummy"')
    end
    if type == :openstack && tenant_id.blank?
      errors.add(:tenant_id, 'must not be blank in case that type is "openstack".')
    end
  end

  def type
    super && super.to_sym
  end

  def client
    CloudConductor::Client.new self
  end

  def used?
    AvailableCloud.where(cloud_id: id).count > 0
  end

  def raise_error_in_use
    fail 'Can\'t destroy cloud that is used in some systems.' if used?
  end
end
