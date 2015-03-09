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
module CloudConductor
  class EventLog
    attr_reader :id, :name, :nodes

    def initialize(response)
      @id = response.values.first['event_id']
      @name = response.values.first['type']

      @nodes = response.map do |key, value|
        hostname = key.split('/').last
        {
          hostname: hostname,
          return_code: value['return_code'] && value['return_code'].to_i,
          started_at: value['started_at'] && DateTime.parse(value['started_at']),
          finished_at: value['finished_at'] && DateTime.parse(value['finished_at']),
          log: value['log']
        }
      end
    end

    def finished?
      @nodes.all? { |node| node[:return_code] }
    end

    def success?
      @nodes.all? { |node| node[:return_code] == 0 }
    end

    def as_json(options = {})
      result = {
        id: @id,
        type: @name,
        succeeded: success?,
        finished: finished?
      }
      result[:results] = @nodes if options[:detail]
      result
    end
  end
end
