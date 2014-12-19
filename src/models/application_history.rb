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

class ApplicationHistory < ActiveRecord::Base
  self.inheritance_column = nil

  before_save :allocate_version, unless: -> { version }
  before_save :consul_request, if: -> { !deployed? && application.system.ip_address }

  belongs_to :application

  validates :application, presence: true
  validates :domain, presence: true
  validates :type, presence: true
  validates :protocol, presence: true, inclusion: { in: %w(http https git) }
  validates :url, presence: true, format: { with: URI.regexp }

  validates_each :parameters do |record, attr, value|
    begin
      JSON.parse(value) unless value.nil?
    rescue JSON::ParserError
      record.errors.add(attr, 'is malformed or invalid json string')
    end
  end

  after_initialize do
    self.status ||= :not_yet
  end

  def status
    super && super.to_sym
  end

  def allocate_version
    today = Date.today.strftime('%Y%m%d')

    if /#{today}-(\d+)/.match application.latest_version
      version_num = (Regexp.last_match[1].to_i + 1).to_s.rjust(3, '0')
      self.version = "#{today}-#{version_num}"
    else
      self.version = "#{today}-001"
    end
  end

  def application_payload
    payload = {}
    payload[:domain] = domain
    payload[:type] = type
    payload[:version] = version
    payload[:protocol] = protocol
    payload[:url] = url
    payload[:revision] = revision if revision
    payload[:pre_deploy] = pre_deploy if pre_deploy
    payload[:post_deploy] = post_deploy if post_deploy

    payload[:parameters] = JSON.parse(parameters || '{}', symbolize_names: true)

    payload
  end

  def consul_request
    payload = {
      cloudconductor: {
        applications: {
        }
      }
    }

    payload[:cloudconductor][:applications][application.name] = application_payload
    application.system.consul.event.sync_fire(:deploy, payload)

    self.status = :deployed
  end

  def deployed?
    status == :deployed
  end

  def dup
    history = super
    history.status = :not_yet
    history
  end
end
