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
  module Patches
    class AddIAMUser < Patch
      include PatchUtils

      def initialize
      end

      def need?(template, _parameters)
        return false unless template[:Resources]
        !template[:Resources].select(&type?('AWS::AutoScaling::LaunchConfiguration')).empty?
      end

      def apply(template, _parameters)
        iam_user = JSON.parse <<-'EOS'
          {
            "IAMUser": {
              "Type": "AWS::IAM::User"
            }
          }
        EOS

        template = template.deep_dup
        template[:Resources].update iam_user

        template
      end
    end
  end
end
