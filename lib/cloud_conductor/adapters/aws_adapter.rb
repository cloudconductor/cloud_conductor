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

      def initialize(options = {})
        @post_processes = []
        @options = options
      end

      def create_stack(name, template, parameters)
        cloud_formation.stacks.create convert_name(name), template, parameters: convert_parameters(parameters)
      end

      def update_stack(name, template, parameters)
        cloud_formation.stacks[convert_name(name)].update(template: template, parameters: convert_parameters(parameters))
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

      def get_stack_status(name)
        cloud_formation.stacks[convert_name(name)].status.to_sym
      end

      def get_stack_events(name)
        cloud_formation.stacks[convert_name(name)].events
      end

      def get_outputs(name)
        outputs = {}
        cloud_formation.stacks[convert_name(name)].outputs.each do |output|
          outputs[output.key] = output.value
        end

        outputs
      end

      def availability_zones
        ec2.availability_zones.map(&:name)
      end

      def destroy_stack(name)
        stack = cloud_formation.stacks[convert_name(name)]
        stack.delete if stack
      end

      def destroy_image(image_id)
        image = ec2.images[image_id]
        return unless image.exists?

        snapshot_ids = image.block_device_mappings.values.map do |block_device_mapping|
          block_device_mapping[:snapshot_id]
        end

        image.deregister

        snapshot_ids.each do |snapshot_id|
          ec2.snapshots[snapshot_id].delete
        end
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

      def cloud_formation
        AWS::CloudFormation.new aws_options(@options)
      end

      def ec2
        AWS::EC2.new aws_options(@options)
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
