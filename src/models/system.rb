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

class System < ActiveRecord::Base
  before_destroy :destroy_stack

  has_many :available_clouds, dependent: :destroy
  has_many :clouds, through: :available_clouds

  before_save :enable_monitoring, if: -> { monitoring_host_changed? }
  before_save :update_dns, if: -> { ip_address }

  scope :in_progress, -> { where(ip_address: nil) }

  validates :name, presence: true
  validates :template_url, format: { with: URI.regexp }, allow_blank: true
  validates :clouds, presence: true

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

  validate do
    errors.add(:clouds, 'can\'t contain duplicate cloud in clouds attribute') unless clouds.size == clouds.uniq.size
  end

  before_create do
    self.template_body = open(template_url).read if template_body.nil?
    self.template_url = nil

    available_clouds.sort_by(&:priority).reverse.each do |available_cloud|
      cloud = available_cloud.cloud
      begin
        cloud.client.create_stack name, template_body, parameters, cloud.attributes
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
    system = super

    matches = name.match(/^(.*?)(_(\d+))?$/)
    base_name = matches[1]
    number = (matches[3] || 0).to_i

    system.name = format('%s_%d', base_name, (number + 1))
    system.ip_address = nil

    available_clouds.each do |available_cloud|
      system.add_cloud available_cloud.cloud, available_cloud.priority
    end

    system
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
    cloud = available_clouds.active
    cloud.client.get_stack_status name, cloud.attributes
  rescue
    :ERROR
  end

  def outputs
    cloud = available_clouds.active
    cloud.client.get_outputs name, cloud.attributes
  rescue
    {}
  end

  def destroy_stack
    cloud = available_clouds.active
    cloud.client.destroy_stack name, cloud.attributes
  end
end
