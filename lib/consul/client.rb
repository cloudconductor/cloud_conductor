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
require 'consul/client/kv'
require 'consul/client/event'
require 'consul/client/catalog'

module Consul
  class Client
    attr_reader :kv, :event, :catalog

    def initialize(hosts, port = 8500, options = {})
      fail 'Consul::Client require host option' unless hosts

      hosts = hosts.split(',').map(&:strip) if hosts.is_a? String
      @faradaies = hosts.map do |host|
        if options[:ssl]
          url = URI::HTTPS.build(host: host, port: port, path: '/v1')
          Faraday.new url, ssl: options[:ssl_options]
        else
          url = URI::HTTP.build(host: host, port: port, path: '/v1')
          Faraday.new url
        end
      end

      @kv = Consul::Client::KV.new @faradaies, options
      @event = Consul::Client::Event.new @faradaies, options
      @catalog = Consul::Client::Catalog.new @faradaies
    end

    def running?
      @faradaies.any? { |faraday| faraday.get('/').success? }
    rescue
      false
    end

    def inspect
      object_id = '0x%014x'.format(self.object_id * 2)
      "#<#{self.class.name}:#{object_id}>"
    end
  end
end
