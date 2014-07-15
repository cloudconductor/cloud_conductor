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
    describe AddCFNCredentials do
      before do
        @patch = AddCFNCredentials.new

        @template = JSON.parse <<-EOS
          {
            "Resources": {
              "Sample": {
                "Type": "AWS::EC2::RouteTable",
                "Properties": {
                  "VpcId": { "Ref": "VPC" }
                }
              },
              "LaunchConfig": {
                "Type": "AWS::AutoScaling::LaunchConfiguration",
                "Metadata" : {
                  "Comment": "Launch instance from AMI",
                  "AWS::CloudFormation::Init": {
                    "config": {
                    }
                  }
                }
              },
              "IAMUser": {
                 "Type": "AWS::IAM::User"
              },
              "IAMKey": {
                "Type": "AWS::IAM::AccessKey",
                "Properties": {
                  "UserName": { "Ref": "IAMUser" }
                }
              }
            }
          }
        EOS

        @template = @template.with_indifferent_access
      end

      it 'extend Patch class' do
        expect(AddCFNCredentials.superclass).to eq(Patch)
      end

      describe '#ensure' do
        it 'construct Hashes to files' do
          result = @patch.ensure({}, {})
          expect(result[:Resources]).to be_is_a Hash
          expect(result[:Resources][:LaunchConfig]).to be_is_a Hash
          expect(result[:Resources][:LaunchConfig][:Metadata]).to be_is_a Hash
          expect(result[:Resources][:LaunchConfig][:Metadata]['AWS::CloudFormation::Init']).to be_is_a Hash
          expect(result[:Resources][:LaunchConfig][:Metadata]['AWS::CloudFormation::Init'][:config]).to be_is_a Hash
        end
      end

      describe '#apply' do
        it 'add files resource' do
          expect(@template[:Resources][:LaunchConfig][:Metadata]['AWS::CloudFormation::Init'][:config].size).to eq(0)
          expect(@template[:Resources][:LaunchConfig][:Metadata]['AWS::CloudFormation::Init'][:config][:files]).to be_nil
          result = @patch.apply @template, {}
          expect(result[:Resources][:LaunchConfig][:Metadata]['AWS::CloudFormation::Init'][:config].size).to eq(1)
          expect(result[:Resources][:LaunchConfig][:Metadata]['AWS::CloudFormation::Init'][:config][:files]).not_to be_nil
          result = @patch.apply result, {}
          expect(result[:Resources][:LaunchConfig][:Metadata]['AWS::CloudFormation::Init'][:config].size).to eq(1)
        end

        it 'doesn\'t affect to other resources' do
          original = @template[:Resources][:Sample].deep_dup

          expect(@template[:Resources][:Sample]).to eq(original)
          result = @patch.apply @template, {}
          expect(result[:Resources][:Sample]).to eq(original)
        end

        it 'doesn\'t affect to source template' do
          original_template = @template.deep_dup

          expect(original_template).to eq(@template)
          @patch.apply @template, {}
          expect(original_template).to eq(@template)
        end
      end
    end
  end
end
