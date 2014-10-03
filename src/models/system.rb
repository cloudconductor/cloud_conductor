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
class System < ActiveRecord::Base
  before_destroy :destroy_stack

  has_many :candidates, dependent: :destroy
  has_many :clouds, through: :candidates
  has_many :applications, dependent: :destroy

  belongs_to :pattern

  before_save :create_stack, if: -> { status == :NOT_CREATED }
  before_save :enable_monitoring, if: -> { monitoring_host_changed? }
  before_save :update_dns, if: -> { ip_address }

  scope :in_progress, -> { where(ip_address: nil) }

  validates :name, presence: true, uniqueness: true
  validates :pattern, presence: true
  validates :clouds, presence: true

  validates_each :template_parameters, :parameters do |record, attr, value|
    begin
      JSON.parse(value) unless value.nil?
    rescue JSON::ParserError
      record.errors.add(attr, 'is malformed or invalid json string')
    end
  end

  validate do
    errors.add(:clouds, 'can\'t contain duplicate cloud in clouds attribute') unless clouds.size == clouds.uniq.size

    if pattern
      errors.add(:pattern, 'can\'t use pattern that contains uncompleted image') unless pattern.status == :created
    end
  end

  def create_stack
    candidates.sort_by(&:priority).reverse.each do |candidate|
      cloud = candidate.cloud
      begin
        cloud.client.create_stack name, pattern, JSON.parse(template_parameters).with_indifferent_access
      rescue => e
        Log.info("Create stack on #{cloud.name} ... FAILED")
        Log.error(e)
      else
        candidate.active = true
        Log.info("Create stack on #{cloud.name} ... SUCCESS")
        break
      end
    end
  end

  def add_cloud(cloud, priority)
    clouds << cloud

    candidate = candidates.find do |c|
      c.cloud_id == cloud.id
    end
    candidate.priority = priority

    clouds
  end

  def dup
    system = super

    basename = name.sub(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, '')
    system.name = "#{basename}-#{SecureRandom.uuid}"
    system.ip_address = nil

    candidates.each do |candidate|
      system.add_cloud candidate.cloud, candidate.priority
    end

    system.applications = applications.map do |application|
      duplicated_application = application.dup
      duplicated_application.histories = application.histories.map(&:dup)
      duplicated_application
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
    cloud = candidates.active
    return :NOT_CREATED if cloud.nil?
    cloud.client.get_stack_status name
  rescue
    :ERROR
  end

  def outputs
    cloud = candidates.active
    cloud.client.get_outputs name
  rescue
    {}
  end

  def destroy_stack
    cloud = candidates.active
    cloud.client.destroy_stack name if cloud
  end

  def serf
    fail 'ip_address does not specified' unless ip_address

    Serf::Client.new host: ip_address
  end

  def send_application_payload
    return if applications.empty?

    payload = {
      cloudconductor: {
        applications: {
        }
      }
    }

    applications.map(&:latest).compact.reject(&:deployed?).each do |history|
      payload[:cloudconductor][:applications][history.application.name] = history.application_payload
    end

    consul = Consul::Client.connect host: ip_address
    consul.kv.merge Serf::Client::PAYLOAD_KEY, payload
  end

  def deploy_applications
    return if applications.empty?

    serf.call('event', 'deploy')

    applications.map(&:latest).compact.reject(&:deployed?).each do |history|
      history.status = :deployed
      history.save!
    end
  end
end
