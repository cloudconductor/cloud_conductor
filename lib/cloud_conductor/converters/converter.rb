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
  module Converters
    class Converter
      attr_reader :patches

      def initialize
        @patches = []
      end

      def convert(template, parameters)
        template = ensure_hash(template)
        parameters = ensure_hash(parameters)

        @patches.each do |patch|
          template = patch.apply(template, parameters)
        end

        template
      end

      def add_patch(patch)
        @patches << patch
      end

      def ensure_hash(obj)
        obj = JSON.parse(obj) if obj.is_a? String
        obj = obj.with_indifferent_access
        obj.deep_dup
      end
    end
  end
end
