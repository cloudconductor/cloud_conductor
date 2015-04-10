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
  module Adapters
    class AWSAdapter < AbstractAdapter
      TYPE = :aws

      def initialize
        @post_processes = []
      end

      def create_stack(name, template, parameters, options = {})
        cloud_formation(options).stacks.create convert_name(name), template, parameters: convert_parameters(parameters)
      end

      def update_stack(name, template, parameters, options = {})
        cloud_formation(options).stacks[convert_name(name)].update(template: template, parameters: convert_parameters(parameters))
      rescue => e
        if e.message == 'No updates are to be performed.'
          Log.info "Ignore updating stack(#{name})"
          Log.info e.message
        else
          Log.warn "Some error has occurred while updating stack(#{name})"
          Log.warn e.message
          raise
        end
      end

      def get_stack_status(name, options = {})
        cloud_formation(options).stacks[convert_name(name)].status.to_sym
      end

      def get_outputs(name, options = {})
        outputs = {}
        cloud_formation(options).stacks[convert_name(name)].outputs.each do |output|
          outputs[output.key] = output.value
        end

        outputs
      end

      def get_availability_zones(options = {})
        ec2(options).availability_zones.map(&:name)
      end

      def destroy_stack(name, options = {})
        stack = cloud_formation(options).stacks[convert_name(name)]
        stack.delete if stack
      end

      def destroy_image(name, options = {})
        image = ec2(options).images[name]
        image.deregister if image.exists?
      end

      def post_process
        @post_processes.each(&:call)
      end

      private

      def aws_options(options = {})
        options = options.with_indifferent_access

        aws_options = {}
        aws_options[:access_key_id] = options[:key]
        aws_options[:secret_access_key] = options[:secret]
        aws_options[:region] = options[:entry_point] if options[:entry_point]

        aws_options
      end

      def cloud_formation(options = {})
        AWS::CloudFormation.new aws_options(options)
      end

      def ec2(options = {})
        AWS::EC2.new aws_options(options)
      end

      def convert_name(name)
        name.gsub('_', '-')
      end

      def convert_parameters(parameters)
        parameters.each_with_object({}) { |(key, value), hash| hash[key] = value.to_s }
      end
    end
  end
end
