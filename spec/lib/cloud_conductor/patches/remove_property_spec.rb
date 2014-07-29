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
                  "Dummy": "DummyValue",
                  "Dummy2": {
                    "Dummy3": "DummyValue3"
                  }
                }
              },
              "Sample2": {
                "Type": "AWS::EC2::RouteTable",
                "Properties": {
                  "Dummy": "DummyValue",
                  "Dummy2": ["DummyValue2"]
                }
              },
              "Sample3": {
                "Type": "AWS::EC2::RouteTable",
                "Properties": {
                  "array1": [{
                    "hash1": {
                      "array2": [{
                        "hash2": {
                          "key1": "value1",
                          "key2": "value2"
                        }
                      }]
                    }
                  }]
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

      describe '#ensure' do
        it 'append Resources hash if hasn\'t it' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'Dummy'
          result = patch.ensure({}, {})
          expect(result.keys).to match_array([:Resources])
        end
      end

      describe '#apply' do
        it 'doesn\'t affect resources outline' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'Dummy'

          expect(@template[:Resources].keys).to match_array(%w(Route Sample1 Sample2 Sample3))
          result = patch.apply @template, {}
          expect(result[:Resources].keys).to match_array(%w(Route Sample1 Sample2 Sample3))
        end

        it 'remove specified property from specified resource' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'Dummy'

          resources = @template[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy2))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy2))
        end

        it 'remove multiple properties from specified resource' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', %w(Dummy Dummy2)

          resources = @template[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w())
        end

        it 'remove hash properties from specified resource' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'Dummy2.Dummy3'

          resources = @template[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample1][:Properties][:Dummy2].keys).to match_array(%w(Dummy3))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample1][:Properties][:Dummy2]).to be_empty
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
        end

        it 'not remove hash properties from specified resource if the key that does not exist is passed' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'Dummy2.Dummy3.Dummy4'

          resources = @template[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample1][:Properties][:Dummy2].keys).to match_array(%w(Dummy3))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample1][:Properties][:Dummy2].keys).to match_array(%w(Dummy3))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
        end

        it 'not remove if the hash of two hierarchy that does not exist is passed' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'hoge.piyo'

          resources = @template[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample1][:Properties][:Dummy2].keys).to match_array(%w(Dummy3))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample1][:Properties][:Dummy2].keys).to match_array(%w(Dummy3))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
        end

        it 'not remove if the hash of three hierarchy that does not exist is passed' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'hoge.piyo.fuga'

          resources = @template[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample1][:Properties][:Dummy2].keys).to match_array(%w(Dummy3))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample1][:Properties].keys).to match_array(%w(VpcId Dummy Dummy2))
          expect(resources[:Sample1][:Properties][:Dummy2].keys).to match_array(%w(Dummy3))
          expect(resources[:Sample2][:Properties].keys).to match_array(%w(Dummy Dummy2))
        end

        it 'remove property from mixed type of array and hash' do
          patch = RemoveProperty.new 'AWS::EC2::RouteTable', 'array1.hash1.array2.hash2.key1'

          resources = @template[:Resources]
          expect(resources[:Sample3][:Properties].keys).to match_array(%w(array1))
          expect(resources[:Sample3][:Properties][:array1][0][:hash1][:array2][0][:hash2].keys).to match_array(%w(key1 key2))
          result = patch.apply @template, {}

          resources = result[:Resources]
          expect(resources[:Sample3][:Properties].keys).to match_array(%w(array1))
          expect(resources[:Sample3][:Properties][:array1][0][:hash1][:array2][0][:hash2].keys).to match_array(%w(key2))
        end
      end
    end
  end
end
