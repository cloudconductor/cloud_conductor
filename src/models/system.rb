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

class System < ActiveRecord::Base # rubocop:disable ClassLength
  has_many :candidates, dependent: :destroy
  has_many :clouds, through: :candidates
  has_many :applications, dependent: :destroy
  has_many :stacks

  before_destroy :destroy_stacks, unless: -> { stacks.empty? }

  before_save :update_dns, if: -> { ip_address }
  before_save :enable_monitoring, if: -> { monitoring_host_changed? }

  validates :name, presence: true, uniqueness: true
  validates :clouds, presence: true

  validate do
    errors.add(:clouds, 'can\'t contain duplicate cloud in clouds attribute') unless clouds.size == clouds.uniq.size
  end

  after_initialize do
    self.template_parameters ||= '{}'
    self.status ||= :PENDING
  end

  def status
    super && super.to_sym
  end

  def as_json(options = {})
    super options.merge(methods: [:status])
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
    system.monitoring_host = nil
    system.template_parameters = '{}'

    candidates.each do |candidate|
      system.add_cloud candidate.cloud, candidate.priority
    end

    system.applications = applications.map do |application|
      duplicated_application = application.dup
      duplicated_application.histories = application.histories.map(&:dup)
      duplicated_application
    end

    system.stacks = stacks.map(&:dup)

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

  def consul
    fail 'ip_address does not specified' unless ip_address

    token = stacks.first.pattern.consul_secret_key

    options = CloudConductor::Config.consul.options.save.merge(token: token)
    Consul::Client.new(ip_address, CloudConductor::Config.consul.port, options)
  end

  def event
    fail 'ip_address does not specified' unless ip_address

    token = stacks.first.pattern.consul_secret_key

    options = CloudConductor::Config.consul.options.save.merge(token: token)
    CloudConductor::Event.new(ip_address, CloudConductor::Config.consul.port, options)
  end

  TIMEOUT = 1800
  def destroy_stacks
    platforms = stacks.select(&:platform?)
    optionals = stacks.select(&:optional?)
    stacks.delete_all

    Thread.new do
      begin
        sleep 1
        ActiveRecord::Base.connection_pool.disconnect!
        optionals.each(&:destroy)

        Timeout.timeout(TIMEOUT) do
          sleep 10 until optionals.all?(&stack_destroyed?)
        end
      rescue Timeout::Error
        Log.warn "Exceeded timeout while destroying stacks #{optionals}"
      ensure
        platforms.each(&:destroy)
      end
    end
  end

  private

  def stack_destroyed?
    lambda do |stack|
      return true unless stack.exist?
      [:DELETE_COMPLETE, :DELETE_FAILED].include? stack.cloud.client.get_stack_status(stack.name)
    end
  end
end
