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
module Consul
  module Client
    class KV
      def initialize(options = {})
        @options = options

        url = URI::HTTP.build(host: options[:host], port: options[:port], path: '/v1/kv')
        @faraday = Faraday.new url
      end

      def get(key)
        response = @faraday.get(key)
        return nil unless response.success?

        hash = JSON.parse(response.body).first.with_indifferent_access
        value = Base64.decode64 hash[:Value]
        JSON.parse(value).with_indifferent_access
      rescue
        value
      end

      def put(key, value)
        value = value.to_json if value.is_a? Hash
        @faraday.put(key, value)
      end

      def merge(key, value)
        previous = get(key)
        value = previous.deep_merge value if previous.is_a? Hash
        put(key, value)
      end
    end
  end
end
