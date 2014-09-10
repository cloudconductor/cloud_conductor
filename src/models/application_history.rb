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
  before_save :serf_request, if: -> { !deployed? && application.system.ip_address }

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

  def allocate_version
    self.version = application.histories.count + 1
  end

  def serf_request
    application_payload = {}
    application_payload[:domain] = domain
    application_payload[:type] = type
    application_payload[:version] = version
    application_payload[:protocol] = protocol
    application_payload[:url] = url
    application_payload[:revision] = revision if revision
    application_payload[:pre_deploy] = pre_deploy if pre_deploy
    application_payload[:post_deploy] = post_deploy if post_deploy

    application_payload[:parameters] = JSON.parse(parameters || '{}', symbolize_names: true)

    payload = {
      cloudconductor: {
        applications: {
        }
      }
    }

    payload[:cloudconductor][:applications][application.name] = application_payload

    application.system.serf.call('event', 'deploy', payload)

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
