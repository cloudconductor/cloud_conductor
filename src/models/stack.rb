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

# rubocop:disable ClassLength
class Stack < ActiveRecord::Base
  before_destroy :destroy_stack

  belongs_to :system
  belongs_to :pattern

  before_save :create_stack, if: -> { status == :NOT_CREATED }

  scope :in_progress, -> { where(status: :PROGRESS) }

  validates :name, presence: true, uniqueness: true

  validates_each :template_parameters, :parameters do |record, attr, value|
    begin
      JSON.parse(value) unless value.nil?
    rescue JSON::ParserError
      record.errors.add(attr, 'is malformed or invalid json string')
    end
  end
  validate do
    if pattern
      errors.add(:pattern, 'can\'t use pattern that contains uncompleted image') unless pattern.status == :created
    end
  end

  def create_stack
    self.status = :PROGRESS

    system.available_clouds.sort_by(&:priority).reverse.each do |available_cloud|
      cloud = available_cloud.cloud
      begin
        cloud.client.create_stack name, pattern, JSON.parse(template_parameters).with_indifferent_access
      rescue => e
        Log.info("Create stack on #{cloud.name} ... FAILED")
        Log.error(e)
      else
        available_cloud.active = true
        Log.info("Create stack on #{cloud.name} ... SUCCESS")
        break
      end
    end
  end

  def add_cloud(cloud, priority)
    clouds << cloud

    available_cloud = available_clouds.find do |c|
      c.cloud_id == cloud.id
    end
    available_cloud.priority = priority

    clouds
  end

  def dup
    stack = super

    basename = name.sub(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, '')
    stack.name = "#{basename}-#{SecureRandom.uuid}"

    stack
  end

  def enable_monitoring
    zabbix_client = CloudConductor::ZabbixClient.new
    zabbix_client.register self
  end

  def update_dns
    dns_client = CloudConductor::DNSClient.new
    dns_client.update domain, ip_address
  end

  def status
    status = super
    return :CREATED if status == :CREATED
    cloud = system.available_clouds.active
    return :NOT_CREATED if cloud.nil?
    cloud.client.get_stack_status name
  rescue
    :ERROR
  end

  def outputs
    cloud = system.available_clouds.active
    cloud.client.get_outputs name
  rescue
    {}
  end

  def destroy_stack
    cloud = system.available_clouds.active
    cloud.client.destroy_stack name if cloud
  end
end
