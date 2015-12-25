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
  class Client
    class KV
      def initialize(faradaies, options = {})
        @faradaies = faradaies
        @token = options[:token]
      end

      def get(key, is_recurse = false)
        sequential_try do |faraday|
          faraday.params.clear
          faraday.params[:token] = @token
          faraday.params[:recurse] = true if is_recurse
          response = faraday.get("kv/#{key}")
          return nil unless response.success?

          result = {}
          JSON.parse(response.body).each do |entry|
            result[entry['Key']] = safety_parse(Base64.decode64 entry['Value']) if entry['Value']
          end

          is_recurse ? result : result.values.first
        end
      end

      def put(key, value)
        sequential_try do |faraday|
          value = value.to_json if value.is_a? Hash
          faraday.params = { token: @token }
          faraday.put("kv/#{key}", value)
        end
      end

      def merge(key, value)
        previous = get(key)
        value = previous.deep_merge value if previous.is_a? Hash
        put(key, value)
      end

      private

      def safety_parse(value)
        JSON.parse(value).with_indifferent_access
      rescue
        value
      end

      def sequential_try
        fail "Block doesn't given" unless block_given?

        @faradaies.find do |faraday|
          begin
            break yield faraday
          rescue
            nil
          end
        end
      end
    end
  end
end
