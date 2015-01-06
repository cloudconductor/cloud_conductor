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
require_relative 'event_results'

module Consul
  module Client
    class Event
      PAYLOAD_KEY = 'cloudconductor/parameters'
      TIMEOUT = 1800

      def initialize(faraday, options = {})
        @faraday = faraday
        @token = options[:token]

        @kv = KV.new @faraday, options
      end

      def fire(event, payload = {})
        @kv.merge PAYLOAD_KEY, payload

        response = @faraday.put("event/fire/#{event}", @token)
        return nil unless response.success?

        JSON.parse(response.body)['ID']
      end

      def sync_fire(event, payload = {})
        event_id = fire(event, payload)
        event_results = nil
        Timeout.timeout(TIMEOUT) do
          loop do
            event_results = get(event_id)
            break if event_results && event_results.finished?
            sleep 5
          end
        end

        unless event_results.success?
          result_log = {}
          event_results.hostnames.each do |hostname|
            result_log[hostname] = event_results[hostname][:log]
          end
          fail result_log.to_json
        end
        event_id
      end

      def get(id)
        response = @faraday.get("kv/event/#{id}?recurse")
        return nil unless response.success?

        EventResults.parse(response.body)
      end
    end
  end
end
