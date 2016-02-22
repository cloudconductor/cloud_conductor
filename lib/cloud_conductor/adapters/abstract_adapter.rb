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
    class AbstractAdapter
      def initialize
        fail "Can't instantiate abstract adapter"
      end

      # rubocop: disable UnusedMethodArgument
      def create_stack(name, template, parameters)
        fail 'Unimplement method'
      end

      def update_stack(name, template, parameters)
        fail 'Unimplement method'
      end

      def get_stack_status(name)
        fail 'Unimplement method'
      end

      def get_stack_events(name)
        fail 'Unimplement method'
      end

      def get_outputs(name)
        fail 'Unimplement method'
      end

      def availability_zones
        fail 'Unimplement method'
      end

      def destroy_stack(name)
        fail 'Unimplement method'
      end

      def destroy_image(name)
        fail 'Unimplement method'
      end

      def post_process
        fail 'Unimplement method'
      end
      # rubocop: enable UnusedMethodArgument
    end
  end
end
