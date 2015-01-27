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
  class PackerClient # rubocop:disable ClassLength
    DEFAULT_OPTIONS = {
      packer_path: '/opt/packer/packer',
      template_path: File.expand_path('../../../config/packer.json', File.dirname(__FILE__)),
      cloudconductor_root: '/opt/cloudconductor',
      cloudconductor_init_url: CloudConductor::Config.cloudconductor_init.url,
      cloudconductor_init_revision: CloudConductor::Config.cloudconductor_init.revision,
      variables: {}
    }

    def initialize(options = {})
      options.reverse_merge! DEFAULT_OPTIONS
      @packer_path = options[:packer_path]
      @template_path = options[:template_path]
      @cloudconductor_root = options[:cloudconductor_root]
      @cloudconductor_init_url = options[:cloudconductor_init_url]
      @cloudconductor_init_revision = options[:cloudconductor_init_revision]

      @vars = options[:variables]
    end

    def build(parameters) # rubocop:disable MethodLength
      clouds = parameters[:clouds]
      operating_systems = parameters[:operating_systems]

      targets = clouds.product operating_systems
      parameters[:only] = targets.map { |cloud, operating_system| "#{cloud}#{BaseImage::SPLITTER}#{operating_system}" }.join(',')
      parameters[:packer_json_path] = create_json(clouds)

      command = build_command parameters
      Thread.new do
        start = Time.now
        status, stdout, stderr = systemu(command)

        Log.debug('--------------stdout------------')
        Log.debug(stdout)
        Log.debug('-------------stderr------------')
        Log.debug(stderr)

        Log.error('Packer failed') unless status.success?
        Log.info("Packer finished in #{Thread.current} (Elapsed time: #{Time.now - start} sec)")

        begin
          ActiveRecord::Base.connection_pool.with_connection do
            yield parse(stdout, parameters[:only]) if block_given?
          end
        rescue => e
          Log.error(e)
        ensure
          FileUtils.rm parameters[:packer_json_path]
        end
      end
    end

    private

    def build_command(parameters)
      @vars.update(repository_url: parameters[:repository_url])
      @vars.update(revision: parameters[:revision])
      vars_text = @vars.map { |key, value| "-var '#{key}=#{value}'" }.join(' ')
      vars_text << " -var 'role=#{parameters[:role]}'"
      vars_text << " -var 'pattern_name=#{parameters[:pattern_name]}'"
      vars_text << " -var 'image_name=#{parameters[:role].gsub(/,\s*/, '-')}'"
      vars_text << " -var 'cloudconductor_root=#{@cloudconductor_root}'"
      vars_text << " -var 'cloudconductor_init_url=#{@cloudconductor_init_url}'"
      vars_text << " -var 'cloudconductor_init_revision=#{@cloudconductor_init_revision}'"
      vars_text << " -var 'consul_secret_key=#{parameters[:consul_secret_key]}'"

      "#{@packer_path} build -machine-readable #{vars_text} -only=#{parameters[:only]} #{parameters[:packer_json_path]}"
    end

    def parse(stdout, only) # rubocop:disable MethodLength
      results = {}
      rows = CSV.parse(stdout, quote_char: "\0")

      only.split(',').each do |target|
        results[target] = {}

        if (row = rows.find(&success?(target)))
          data = row[5]
          results[target][:status] = :SUCCESS
          results[target][:image] = data.split(':').last
          next
        end

        results[target][:status] = :ERROR
        if (row = rows.find(&error1?(target)))
          data = row[3]
          results[target][:message] = data.gsub('%!(PACKER_COMMA)', ',')
          next
        end

        if (row = rows.find(&error2?(target)))
          data = row[4]
          results[target][:message] = data.gsub('%!(PACKER_COMMA)', ',').gsub("==> #{target}: ", '')
          next
        end

        if (row = rows.find(&error3?(target)))
          data = row[4]
          results[target][:message] = data.gsub('%!(PACKER_COMMA)', ',').gsub("--> #{target}: ", '')
          next
        end

        results[target][:message] = 'Unknown error has occurred'
      end

      results.with_indifferent_access
    end

    # rubocop:disable ParameterLists
    def success?(search_target)
      proc { |_timestamp, target, type, _index, subtype, _data| target == search_target && type == 'artifact' && subtype == 'id' }
    end

    def error1?(search_target)
      proc { |_timestamp, target, type, _data| target == search_target && type == 'error' }
    end

    def error2?(search_target)
      proc { |_timestamp, _target, type, subtype, data| type == 'ui' && subtype == 'error' && data =~ /^==>\s*#{search_target}/ }
    end

    def error3?(search_target)
      proc { |_timestamp, _target, type, subtype, data| type == 'ui' && subtype == 'error' && data =~ /^-->\s*#{search_target}/ }
    end
    # rubocop:enable ParameterLists

    def create_json(cloud_names)
      clouds = Cloud.where(name: cloud_names)

      temporary = File.expand_path('../../../tmp/packer/', File.dirname(__FILE__))
      FileUtils.mkdir_p temporary unless Dir.exist? temporary

      json_path = File.expand_path("#{SecureRandom.uuid}.json", temporary)
      template_json = JSON.load(open(@template_path)).with_indifferent_access

      File.open(json_path, 'w') do |f|
        clouds.map(&:base_images).flatten.each do |base_image|
          template_json[:builders].push JSON.parse(base_image.to_json)
        end

        f.write template_json.to_json
      end

      json_path
    end
  end
end
