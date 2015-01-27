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
    class DummyAdapter < AbstractAdapter
      TYPE = :dummy

      def initialize
      end

      # rubocop: disable UnusedMethodArgument
      def create_stack(name, template, parameters, options = {})
      end

      def get_stack_status(name, options = {})
      end

      def destroy_stack(name, options = {})
      end
      # rubocop: enable UnusedMethodArgument
    end
  end
end
