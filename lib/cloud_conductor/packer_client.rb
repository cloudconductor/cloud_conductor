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
      template_path: File.expand_path('../../config/packer.json', File.dirname(__FILE__)),
      patterns_root: '/opt/cloudconductor/patterns',
      variables: {}
    }

    def initialize(options = {})
      options.reverse_merge! DEFAULT_OPTIONS
      @packer_path = options[:packer_path]
      @template_path = options[:template_path]
      @patterns_root = options[:patterns_root]

      @vars = options[:variables]
    end

    def build(repository_url, revision, clouds, operating_systems, role)
      command = build_command repository_url, revision, clouds, operating_systems, role
      Thread.new do
        status, stdout, stderr = systemu(command)
        unless status.success?
          Log.error('Packer failed')
          Log.info('--------------stdout------------')
          Log.info(stdout)
          Log.error('-------------stderr------------')
          Log.error(stderr)
        end

        ActiveRecord::Base.connection_pool.with_connection do
          yield parse(stdout, only) if block_given?
        end
        Log.info("Packer finished in #{Thread.current}")
      end
    end

    private

    def build_command(repository_url, revision, clouds, operating_systems, role)
      @vars.update(repository_url: repository_url)
      @vars.update(revision: revision)
      vars_text = @vars.map { |key, value| "-var '#{key}=#{value}'" }.join(' ')
      vars_text << " -var 'role=#{role}'"
      vars_text << " -var 'patterns_root=#{@patterns_root}'"

      only = (clouds.product operating_systems).map { |cloud, operating_system| "#{cloud}-#{operating_system}" }.join(',')

      packer_json_path = create_json clouds

      "#{@packer_path} build -machine-readable #{vars_text} -only=#{only} #{packer_json_path}"
    end

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

    def create_json(cloud_names)
      clouds = Cloud.where(name: cloud_names)

      temporary = File.expand_path('../../tmp/packer/', File.dirname(__FILE__))
      FileUtils.mkdir_p temporary unless Dir.exist? temporary

      json_path = File.expand_path("#{SecureRandom.uuid}.json", temporary)
      template_json = JSON.load(open(@template_path)).with_indifferent_access

      File.open(json_path, 'w') do |f|
        clouds.map(&:targets).flatten.each do |target|
          template_json[:builders].push JSON.parse(target.to_json)
        end

        f.write template_json.to_json
      end

      json_path
    end
  end
end
