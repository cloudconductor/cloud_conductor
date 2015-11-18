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
require 'open3'
require 'aws-sdk'

module CloudConductor
  class DNSClient
    def initialize
      @config = CloudConductor::Config.dns.configuration
      case @config[:service]
      when 'route53'
        @client = Route53Client.new(@config)
      when 'bind9'
        @client = Bind9Client.new(@config)
      else
        error_message = "Unsupported dns service '#{@config[:service]}'"
        Log.error error_message
        fail error_message
      end
    end

    def update(domain, value, type = 'A')
      @client.update(domain, value, type)
    rescue => e
      Log.error('Some error occurred while requesting to DNS')
      Log.error(e)
      raise
    end
  end

  class Bind9Client
    def initialize(config)
      @config = config
    end

    def update(domain, value, type = 'A')
      dns_keyfile = @config[:key_file]
      dns_server = @config[:server]
      ttl = @config[:ttl]
      command = "server #{dns_server}\n" \
      "update delete #{domain}\n" \
      "send\n" \
      "update add #{domain} #{ttl} #{type} #{value}\n" \
      "send\n"
      Log.debug command
      nsupdate = "sudo /usr/bin/nsupdate -k #{dns_keyfile}"
      Log.debug nsupdate
      out, err, status = Open3.capture3(nsupdate, stdin_data: command)
      Log.debug "out = #{out}"
      Log.debug "err = #{err}"
      Log.debug "status = #{status}"
    end
  end

  class Route53Client
    def initialize(config)
      if config[:access_key].nil? || config[:secret_key].nil?
        fail ArgumentError, 'Need access_key and secret_key to access AWS Route53'
      end
      @config = config
      route53 = AWS::Route53.new(access_key_id: @config[:access_key], secret_access_key: @config[:secret_key])
      @client = route53.client
    end

    def update(domain, value, type = 'A')
      base_domain_name = domain.split('.', 2).last
      hosted_zone = find_hosted_zone(base_domain_name)
      if hosted_zone.nil?
        error_message = "Cannot find AWS Route53 hosted zone to organize '#{base_domain_name}'."
        Log.error error_message
        fail error_message
      end
      existing_record = find_resource_record_set(hosted_zone, domain, type)
      action = existing_record.nil? ? 'CREATE' : 'UPSERT'
      result = create_or_update_resource_record_set(hosted_zone, domain, value, action, type)

      sleep 30 if existing_record.nil?

      result
    end

    private

    def find_hosted_zone(base_domain_name)
      options = {}
      loop do
        begin
          response = @client.list_hosted_zones(options)
          log_response(response)
          hosted_zone = response.data[:hosted_zones].find { |zone| zone[:name] == "#{base_domain_name}." }
          return hosted_zone unless hosted_zone.nil?
          return nil unless response.data[:is_truncated]
          options[:marker] = response.data[:next_marker]
        rescue => e
          log_error(e, :list_hosted_zones, options)
          raise
        end
      end
    end

    def find_resource_record_set(hosted_zone, name, type)
      options = {
        hosted_zone_id: hosted_zone[:id],
        start_record_name: name,
        start_record_type: type
      }
      loop do
        begin
          response = @client.list_resource_record_sets(options)
          log_response(response)
          record_set = response.data[:resource_record_sets].find { |record| record[:name] == "#{name}." && record[:type] == type }
          return record_set unless record_set.nil?
          return nil unless response.data[:is_truncated]
          options[:marker] = response.data[:next_marker]
        rescue => e
          log_error(e, :list_resource_record_sets, options)
          raise
        end
      end
    end

    def create_or_update_resource_record_set(hosted_zone, name, value, action, type = 'A')
      options = {
        hosted_zone_id: hosted_zone[:id],
        change_batch: {
          changes: [{
            action: action,
            resource_record_set: { name: name,
                                   type: type,
                                   ttl: @config[:ttl].to_i,
                                   resource_records: [{ value: value }] }
          }]
        }
      }
      begin
        response = @client.change_resource_record_sets(options)
        log_response(response)
      rescue => e
        log_error(e, :change_resource_record_sets, options)
        return false
      end
      response.successful?
    end

    def log_response(response)
      Log.debug "Request AWS API: #{response.request_type}, #{response.request_options}"
      Log.debug "Response: #{response.data}"
      Log.debug "Error: #{response.error}" unless response.successful?
    end

    def log_error(exception, method_name, options)
      Log.error "AWS::Route53::Client raise exception #{exception.class}:'#{exception.message}' when call #{method_name}"
      Log.debug "Request datails: #{method_name}, #{options}"
    end
  end
end
