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
=begin
  has_many :gateways, dependent: :destroy
  has_many :network_groups, dependent: :destroy
  has_many :machine_groups, dependent: :destroy
  has_many :volumes, dependent: :destroy
  has_many :floating_ips, dependent: :destroy
  has_many :applications, dependent: :destroy
  has_many :credentials, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :machine_filter_groups, dependent: :destroy
  has_many :operations
  has_many :machines, through: :machine_groups

  before_validation :validate_xml
  before_create proc { self.state = 'CREATING' }

  def deploy
    Log.debug(Log.format_method_start(self.class, __method__))
    if self.persisted?
      operation = operations.create!(
        type: Operation::Type::DEPLOY_SYSTEM,
      )
      operation.run
    else
      Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
      fail 'System does not stored yet.'
    end
  end

  def to_h
    template = XmlParser.new(template_xml)
    template_name = template.find('System')[:name]
    {
      id: id,
      name: name,
      template_name: template_name,
      template_xml: template_xml,
      template_uri: template_uri,
      meta_xml: meta_xml,
      status: {
        type: state,
        message: response_message
      },
      create_date: created_at,
      update_date: updated_at,
    }
  end

  def gateway_server_ip
    Log.debug(Log.format_method_start(self.class, __method__))
    machine_group = machine_groups.find { |m| m.role.attribute_id.downcase.include?('zabbix') }
    machine_group.machines.first.floating_ips.first.ip_address
  rescue
    raise
  end

  def dns_server
    Log.debug(Log.format_method_start(self.class, __method__))
    machine_group = machine_groups.find { |m| m.role.attribute_id.downcase.include?('dns') }
    machine_group.machines.first
  rescue
    raise
  end

  private

  def validate_xml
    Log.debug(Log.format_method_start(self.class, __method__))
    true # TBD
  end
=end
end
