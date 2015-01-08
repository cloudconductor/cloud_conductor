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
    class EventResults
      def initialize(response)
        @results = {}
        response.each do |key, value|
          hostname = key.split('/').last
          result = {
            event_id: value['event_id'],
            type: value['type'],
            result: value['result'] && value['result'].to_i,
            start_datetime: value['start_datetime'] && DateTime.parse(value['start_datetime']),
            end_datetime: value['end_datetime'] && DateTime.parse(value['end_datetime']),
            log: value['log']
          }
          @results[hostname] = result
        end
      end

      def size
        @results.size
      end

      def [](hostname)
        @results[hostname]
      end

      def hostnames
        @results.keys
      end

      def finished?
        @results.values.all? { |result| result[:result] }
      end

      def success?
        @results.values.all? { |result| result[:result] == 0 }
      end
    end
  end
end
