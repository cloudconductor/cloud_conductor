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
require_relative 'event_log'

module CloudConductor
  class Event
    PAYLOAD_KEY = 'cloudconductor/parameters'
    TIMEOUT = 1800

    def initialize(host, port = 8500, options = {})
      @token = options[:token]
      @client = Consul::Client.new(host, port, options)
    end

    def fire(name, payload = {}, filter = {})
      @client.kv.merge PAYLOAD_KEY, payload
      @client.event.fire name, @token, filter
    end

    def sync_fire(name, payload = {}, filter = {})
      event_id = fire(name, payload, filter)
      wait(event_id)
      event_log = find(event_id)

      unless event_log.success?
        messages = {}
        event_log.nodes.each do |node|
          messages[node[:hostname]] = node[:log]
        end

        fail "#{name} event has failed.\n#{messages.to_json}"
      end
      event_id
    end

    def wait(event_id)
      event_log = nil
      Timeout.timeout(TIMEOUT) do
        loop do
          event_log = find(event_id)
          break if event_log && event_log.finished?
          sleep 5
        end
      end
    end

    def find(id)
      response = @client.kv.get("event/#{id}", true)
      return nil unless response

      EventLog.new(response)
    end
  end
end
