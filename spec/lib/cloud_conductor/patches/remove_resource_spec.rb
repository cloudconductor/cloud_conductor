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
    describe RemoveResource do
      before do
        @template = JSON.parse <<-EOS
          {
            "Resources": {
              "Route": {
                "Type": "AWS::EC2::Route"
              },
              "Sample1": {
                "Type": "AWS::EC2::RouteTable"
              },
              "Sample2": {
                "Type": "AWS::EC2::RouteTable"
              }
            }
          }
        EOS

        @template = @template.with_indifferent_access
      end

      it 'extend Patch class' do
        expect(RemoveResource.superclass).to eq(Patch)
      end

      describe '#ensure' do
        it 'append Resources hash if hasn\'t it' do
          patch = RemoveResource.new 'AWS::EC2::RouteTable'
          result = patch.ensure({}, {})
          expect(result.keys).to match_array([:Resources])
        end
      end

      describe '#apply' do
        it 'remove specified resource from Resources' do
          patch = RemoveResource.new 'AWS::EC2::Route'

          expect(@template[:Resources].keys).to match_array(%w(Route Sample1 Sample2))
          result = patch.apply @template, {}
          expect(result[:Resources].keys).to match_array(%w(Sample1 Sample2))
        end

        it 'remove multiple resource from Resources' do
          patch = RemoveResource.new 'AWS::EC2::RouteTable'

          expect(@template[:Resources].keys).to match_array(%w(Route Sample1 Sample2))
          result = patch.apply @template, {}
          expect(result[:Resources].keys).to match_array(%w(Route))
        end

        it 'doesn\'t affect to source template' do
          patch = RemoveResource.new 'AWS::EC2::RouteTable'
          original_template = @template.deep_dup

          expect(original_template).to eq(@template)
          patch.apply @template, {}
          expect(original_template).to eq(@template)
        end
      end
    end
  end
end
