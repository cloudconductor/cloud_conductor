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
module Serf
  class Client
    SERF_PATH = 'serf'

    DEFAULT_OPTIONS = {
      port: 7373,
      options: {}
    }

    PAYLOAD_KEY = 'cloudconductor/parameters'

    def initialize(options = {})
      fail 'Serf::Client require host option' unless options[:host]

      options.reverse_merge! DEFAULT_OPTIONS
      @host = options[:host]
      @port = options[:port]
      @options = options[:options]
    end

    def call(main, sub = nil, payload = {})
      consul = Consul::Client.connect host: @host, port: @port
      consul.kv.put PAYLOAD_KEY, payload

      options_text = @options.map { |key, value| "-#{key}=#{value}" }.join(' ')
      command = "#{SERF_PATH} #{main} -rpc-addr=#{@host}:#{@port} #{options_text} #{sub}"
      Log.debug("Execute serf command: #{command}")
      status, stdout, stderr = systemu(command)

      unless status.success?
        Log.error('Serf failed')
        Log.info('--------------stdout------------')
        Log.info(stdout)
        Log.error('-------------stderr------------')
        Log.error(stderr)
        return status, nil
      end

      [status, stdout]
    end
  end
end
