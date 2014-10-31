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
        options = options.with_indifferent_access

        aws_options = {}
        aws_options[:access_key_id] = options[:key]
        aws_options[:secret_access_key] = options[:secret]
        aws_options[:region] = options[:entry_point] if options[:entry_point]

        cf = AWS::CloudFormation.new aws_options
        cf.stacks.create name, template, parameters: parameters
      end

      def get_stack_status(name, options = {})
        options = options.with_indifferent_access

        aws_options = {}
        aws_options[:access_key_id] = options[:key]
        aws_options[:secret_access_key] = options[:secret]
        aws_options[:region] = options[:entry_point] if options[:entry_point]

        cf = AWS::CloudFormation.new aws_options
        cf.stacks[name].status.to_sym
      end

      def get_outputs(name, options = {})
        options = options.with_indifferent_access

        aws_options = {}
        aws_options[:access_key_id] = options[:key]
        aws_options[:secret_access_key] = options[:secret]
        aws_options[:region] = options[:entry_point] if options[:entry_point]

        cf = AWS::CloudFormation.new aws_options
        outputs = {}
        cf.stacks[name].outputs.each do |output|
          outputs[output.key] = output.value
        end

        outputs
      end

      def destroy_stack(name, options = {})
        options = options.with_indifferent_access

        aws_options = {}
        aws_options[:access_key_id] = options[:key]
        aws_options[:secret_access_key] = options[:secret]
        aws_options[:region] = options[:entry_point] if options[:entry_point]

        cf = AWS::CloudFormation.new aws_options
        stack = cf.stacks[name]
        stack.delete if stack
      end

      def post_process
        @post_processes.each(&:call)
      end
    end
  end
end
