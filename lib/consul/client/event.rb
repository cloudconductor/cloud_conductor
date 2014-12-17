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
      def initialize(options = {})
        @options = options

        url = URI::HTTP.build(host: options[:host], port: options[:port], path: '/v1')
        @faraday = Faraday.new url
      end

      def fire(event, _payload = {})
        response = @faraday.put("event/#{event}")
        return nil unless response.success?

        JSON.parse(response.body).with_indifferent_access
      end

      def get(id)
        response = @faraday.get("kv/event/#{id}?recurse")
        return nil unless response.success?

        EventResults.parse(response.body)
      end
    end
  end
end
