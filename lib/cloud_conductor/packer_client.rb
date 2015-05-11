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
      packer_path: CloudConductor::Config.packer.path,
      template_path: File.expand_path('../../config/packer.json', File.dirname(__FILE__)),
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

    def build(images, parameters) # rubocop:disable MethodLength
      parameters[:packer_json_path] = create_json(images)

      command = build_command parameters
      log_path = log_path(images.first.pattern, parameters[:role])
      Thread.new do
        start = Time.now
        begin
          Log.info("Start Packer in #{Thread.current}")
          Log.info("Output packer log to #{log_path}")

          status, _stdout, _stderr = systemu("#{command} > #{log_path} 2>&1")
          fail "Packer failed(exitstatus: #{status.exitstatus})" unless status.success?

          ActiveRecord::Base.connection_pool.with_connection do
            yield parse(IO.read(log_path), images) if block_given?
          end
        rescue => e
          Log.error('Error occurred while executing packer')
          Log.error(e)
          images.each do |image|
            image.update_attributes(status: :ERROR)
          end
        ensure
          Log.info("Packer finished in #{Thread.current} (Elapsed time: #{Time.now - start} sec)")
          FileUtils.rm parameters[:packer_json_path]
        end
      end
    end

    private

    def create_json(images)
      temporary = File.expand_path('../../tmp/packer/', File.dirname(__FILE__))
      FileUtils.mkdir_p temporary unless Dir.exist? temporary

      json_path = File.expand_path("#{SecureRandom.uuid}.json", temporary)
      template_json = JSON.load(open(@template_path)).with_indifferent_access

      File.open(json_path, 'w') do |f|
        images.map(&:base_image).each do |base_image|
          template_json[:builders].push base_image.builder
        end

        f.write template_json.to_json
      end

      json_path
    end

    def build_command(parameters)
      vars = @vars.dup
      vars[:repository_url] = parameters[:repository_url]
      vars[:revision] = parameters[:revision]
      vars[:role] = parameters[:role]
      vars[:pattern_name] = parameters[:pattern_name]
      vars[:image_name] = parameters[:role].gsub(/,\s*/, '-')
      vars[:cloudconductor_root] = @cloudconductor_root
      vars[:cloudconductor_init_url] = @cloudconductor_init_url
      vars[:cloudconductor_init_revision] = @cloudconductor_init_revision
      vars[:consul_secret_key] = parameters[:consul_secret_key]
      vars_text = vars.map { |key, value| " -var '#{key}=#{escape(value)}'" }.join(' ')

      "#{@packer_path} build -machine-readable #{vars_text} #{parameters[:packer_json_path]}"
    end

    def escape(value)
      return nil unless value
      value.gsub("'", Regexp.escape("'\\''"))
    end

    def log_path(pattern, role)
      log_directory = File.expand_path('../../log/packer', File.dirname(__FILE__))
      FileUtils.mkdir_p log_directory unless Dir.exist? log_directory

      date = DateTime.now.strftime('%Y%m%d%H%M%S')
      File.expand_path("#{pattern.name}-#{role.gsub(/,\s*/, '-')}_#{date}", log_directory)
    end

    def parse(stdout, images) # rubocop:disable MethodLength
      results = {}
      rows = CSV.parse(stdout, quote_char: "\0")

      images.each do |image|
        name = image.name
        results[name] = {}

        if (row = rows.find(&success?(name)))
          data = row[5]
          results[name][:status] = :SUCCESS
          results[name][:image] = data.split(':').last
          next
        end

        results[name][:status] = :ERROR
        if (row = rows.find(&error1?(name)))
          data = row[3]
          results[name][:message] = data.gsub('%!(PACKER_COMMA)', ',')
          next
        end

        if (row = rows.find(&error2?(name)))
          data = row[4]
          results[name][:message] = data.gsub('%!(PACKER_COMMA)', ',').gsub("==> #{name}: ", '')
          next
        end

        if (row = rows.find(&error3?(name)))
          data = row[4]
          results[name][:message] = data.gsub('%!(PACKER_COMMA)', ',').gsub("--> #{name}: ", '')
          next
        end

        results[name][:message] = 'Unknown error has occurred'
      end

      results
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
  end
end
