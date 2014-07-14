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
    describe RemoveProperty do
      before do
        @template = JSON.parse <<-EOS
          {
            "Resources": {
              "Route": {
                "Type": "AWS::EC2::Route"
              },
              "Sample1": {
                "Type": "AWS::EC2::RouteTable",
                "Properties": {
                  "VpcId": { "Ref": "VPC" },
                  "Dummy": "DummyValue"
                }
              },
              "Sample2": {
                "Type": "AWS::EC2::RouteTable",
                "Properties": {
                  "Dummy": "DummyValue",
                  "Dummy2": "DummyValue2"
                }
              }
            }
          }
        EOS

        @template = @template.with_indifferent_access
      end

      it 'extend Patch class' do
        expect(RemoveProperty.superclass).to eq(Patch)
      end

      describe '#apply' do
        it 'doesn\'t affect resources outline' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'Dummy'

          expect(@template[:Resources].keys).to match_array(%w(Route Sample1 Sample2))
          result = patch.apply @template, {}
          expect(result[:Resources].keys).to match_array(%w(Route Sample1 Sample2))
        end

        it 'remove specified property from specified resource' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'Dummy'

          resources = @template[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy2))
        end

        it 'remove multiple properties from specified resource' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', %w(Dummy Dummy2)

          resources = @template[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w())
        end
      end
    end
  end
end
