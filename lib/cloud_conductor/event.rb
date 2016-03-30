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
  class Event
    def initialize(hosts, port = 8500, options = {})
      @client = Consul::Client.new(hosts, port, options)
    end

    def fire(name, payload = {}, filter = {})
      Log.info "#{name} event will be fire"
      payload.each do |key, value|
        @client.kv.merge key, value
      end
      @client.event.fire name, filter
    end

    def sync_fire(name, payload = {}, filter = {})
      event_id = fire(name, payload, filter)
      wait(event_id)
      result = find(event_id)

      if result.success?
        Log.info "#{name} event has finished successfully"
      else
        details = JSON.pretty_generate(JSON.parse(result.refresh!.to_json))
        fail "#{name} event has failed.\n#{details}"
      end
      event_id
    end

    def wait(event_id)
      Timeout.timeout(CloudConductor::Config.event.timeout) do
        loop do
          result = find(event_id)
          break if result && result.finished?
          sleep 5
        end
      end
    end

    def list
      Metronome::EventResult.list(@client)
    end

    def find(id)
      result = Metronome::EventResult.find(@client, id)
      result.refresh! if result
    end
  end
end
