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
require 'mixlib/log'

module Core
  module LogFormatter
    def format_exception(e)
      http_body = e.respond_to?('http_body') ? "(#{e.http_body})" : ''
      "#{e.class}: #{e.message}#{http_body}\n#{e.backtrace.join("\n")}"
    end

    def format_error_params(error_class, error_method, params)
      msg = params.reduce('') { |res, (k, v)| res << "#{k}: #{v}\n" }
      "Error occurred: #{error_class}.#{error_method} with\n#{msg}"
    end

    def format_debug_param(param)
      return nil unless param.is_a?(Hash)
      param.reduce('') { |res, (k, v)| res << "#{k}: #{v}" }
    end

    def format_method_start(klass, method)
      "Starting method #{klass}.#{method}"
    end
  end
end

class Log
  extend Core::LogFormatter
  extend Mixlib::Log

  def initialize(logdev, loglevel)
    Log.logger = Logger.new(logdev)
    Log.logger.level = convert_loglevel(loglevel)
    Log.formatter = proc do |severity, datetime, progname, msg|
      thread = Thread.current || ''
      "[#{severity[0]}, #{datetime.iso8601(3)} #{thread}] #{severity} -- : #{msg}\n"
    end
    Log.debug('Start logging')
  end

  private

  def convert_loglevel(loglevel)
    case loglevel
    when :fatal
      Logger::FATAL
    when :error
      Logger::ERROR
    when :warn
      Logger::WARN
    when :info
      Logger::INFO
    when :debug
      Logger::DEBUG
    else
      Logger::ERROR
    end
  end
end
