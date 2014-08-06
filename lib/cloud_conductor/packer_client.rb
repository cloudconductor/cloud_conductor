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
require 'csv'

module CloudConductor
  class PackerClient
    DEFAULT_OPTIONS = {
      packer_path: '/opt/packer/packer',
      packer_json_path: File.expand_path('../../config/packer.json', File.dirname(__FILE__))
    }

    def initialize(options = {})
      options.reverse_merge! DEFAULT_OPTIONS
      @packer_path = options[:packer_path]
      @packer_json_path = options[:packer_json_path]
      @vars = options.except(:packer_path, :packer_json_path)
    end

    def build(repository_url, revision, clouds, oss, role)
      only = (clouds.product oss).map { |cloud, os| "#{cloud}-#{os}" }.join(',')
      @vars.update(repository_url: repository_url)
      @vars.update(revision: revision)
      vars_text = @vars.map { |key, value| "-var '#{key}=#{value}'" }.join(' ')
      command = "#{@packer_path} build -machine-readable #{vars_text} -var 'role=#{role}' -only=#{only} #{@packer_json_path}"
      Thread.new do
        _status, stdout, _stderr = systemu(command)
        yield parse(stdout, only) if block_given?
      end
    end

    private

    # rubocop:disable MethodLength
    def parse(stdout, only)
      results = {}
      rows = CSV.parse(stdout, quote_char: "\0")

      only.split(',').each do |key|
        results[key] = {}

        if (row = rows.find(&success?(key)))
          results[key][:status] = :success
          results[key][:image] = row[5].split(':').last
          next
        end

        results[key][:status] = :error
        if (row = rows.find(&error1?(key)))
          results[key][:message] = row[3].gsub('%!(PACKER_COMMA)', ',')
          next
        end

        if (row = rows.find(&error2?(key)))
          results[key][:message] = row[4].gsub('%!(PACKER_COMMA)', ',').gsub("==> #{key}: ", '')
          next
        end

        if (row = rows.find(&error3?(key)))
          results[key][:message] = row[4].gsub('%!(PACKER_COMMA)', ',').gsub("--> #{key}: ", '')
          next
        end

        results[key][:message] = 'Unknown error has occurred'
      end

      results.with_indifferent_access
    end
    # rubocop:enable MethodLength

    # rubocop:disable ParameterLists
    def success?(key)
      proc { |_timestamp, target, type, _index, subtype, _data| target == key && type == 'artifact' && subtype == 'id' }
    end

    def error1?(key)
      proc { |_timestamp, target, type, _data| target == key && type == 'error' }
    end

    def error2?(key)
      proc { |_timestamp, _target, type, subtype, data | type == 'ui' && subtype == 'error' && data =~ /^==>\s*#{key}/ }
    end

    def error3?(key)
      proc { |_timestamp, _target, type, subtype, data | type == 'ui' && subtype == 'error' && data =~ /^-->\s*#{key}/ }
    end
    # rubocop:enable ParameterLists

    def create_json(clouds)
      # it return json path that is created by #create_json in tmp directory
      '/var/www/develop/takezawa/core/tmp/packer/12345678-1234-1234-1234-123456789abc.json'


      # it write valid json to tempoarary packer.json
      File.open('hoge') do |f|
        f.write <<-EOS
          {
            "variables": {},
            "builders": [
              {
                name: "cloud_aws_4"
              },
              {
                name: "cloud_openstack_4"
              }
            ]
          }
        EOS
      end
    end
  end
end
