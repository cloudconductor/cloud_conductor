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
    describe 'PatchUtils' do
      include PatchUtils

      describe '#type?' do
        it 'return lambda' do
          is_sample = type?('Sample')
          expect(is_sample.class).to eq(Proc)
          expect(is_sample.lambda?).to be_truthy
        end

        it 'return true when resource has Sample type' do
          is_sample = type?('Sample')
          resource = { Type: 'Sample' }
          expect(is_sample.call('Key', resource)).to be_truthy
        end

        it 'return false when resource hasn\'t Sample type' do
          is_sample = type?('Sample')
          resource = { Type: 'Test' }
          expect(is_sample.call('Key', resource)).to be_falsey
        end
      end

      describe '#remove_resource' do
        before do
          @template = JSON.parse <<-EOS
            {
              "Resources": {
                "Route": {
                  "Type": "AWS::EC2::Route"
                },
                "Sample": {
                  "Type": "AWS::EC2::RouteTable",
                  "Properties": {
                    "VpcId": { "Ref": "VPC" }
                  }
                },
                "Sample2": {
                  "DependsOn": ["Route"],
                  "Type": "Sample2",
                  "Properties": {
                    "Dummy": "DummyValue"
                  }
                },
                "Depend": {
                  "Type": "Dummy",
                  "Properties": {
                    "Property": { "Fn::Join": ["", [
                      "Hoge"
                    ]] },
                    "Target": { "Ref": "Route"}
                  }
                },
                "ArrayDepend": {
                  "Type": "Dummy",
                  "Properties": {
                    "Property": { "Fn::Join": ["", [
                      "Hoge",
                      { "Ref": "Route" }
                    ]] }
                  }
                }
              },
              "Outputs": {
                "Ref": {
                  "Value": { "Ref": "Route" },
                  "Description": "Route resource id"
                },
                "Att": {
                  "Value": { "Fn::GetAtt": ["Route", "Attribute"] },
                  "Description": "Route resource id"
                },
                "Dummy": {
                  "Value": { "Ref": "Sample2" },
                  "Description": "Route resource id"
                }
              }
            }
          EOS

          @template = @template.with_indifferent_access
        end

        it 'remove target resource and dependency resources' do
          expect(@template[:Resources].keys).to match_array(%w(Route Sample Sample2 Depend ArrayDepend))
          result = remove_resource @template, 'Route'
          expect(result[:Resources].keys).to match_array(%w(Sample Sample2 ArrayDepend))
        end

        it 'doesn\'t affect to other resources' do
          original = @template[:Resources][:Sample].deep_dup

          expect(@template[:Resources][:Sample]).to eq(original)
          result = remove_resource @template, 'Route'
          expect(result[:Resources][:Sample]).to eq(original)
        end

        it 'doesn\'t affect to source template' do
          original_template = @template.deep_dup

          expect(original_template).to eq(@template)
          remove_resource @template, 'Route'
          expect(original_template).to eq(@template)
        end

        it 'remove reference to dependency resource from array' do
          values = @template[:Resources][:ArrayDepend][:Properties][:Property][:"Fn::Join"].last
          expect(values.size).to eq(2)
          expect(values[0]).to eq('Hoge')
          expect(values[1]).to eq('Ref' => 'Route')

          result = remove_resource @template, 'Route'

          values = result[:Resources][:ArrayDepend][:Properties][:Property][:"Fn::Join"].last
          expect(values.size).to eq(1)
          expect(values[0]).to eq('Hoge')
        end

        it 'remove dependsOn condition from dependency resources' do
          expect(@template[:Resources][:Sample2][:DependsOn]).to eq(['Route'])
          result = remove_resource @template, 'Route'
          expect(result[:Resources][:Sample2][:DependsOn]).to eq([])
        end

        it 'remove outputs entity that has dependency with removed resource' do
          expect(@template[:Outputs].keys).to match_array(%w(Ref Att Dummy))
          result = remove_resource @template, 'Route'
          expect(result[:Outputs].keys).to match_array(%w(Dummy))
        end
      end

      describe '#contains_ref' do
        it 'return true when template has Ref entry with specified resource' do
          obj = { Ref: 'Route' }
          expect(contains_ref(obj, ['Route'])).to be_truthy
        end

        it 'return true when deep hash has Ref entry' do
          obj = { Dummy: { Ref: 'Route' } }
          expect(contains_ref(obj, ['Route'])).to be_truthy
        end

        it 'return true when deep array has Ref entry' do
          obj = { Dummy: [{ Ref: 'Route' }] }
          expect(contains_ref(obj, ['Route'])).to be_truthy
        end

        it 'return false when template hasn\'t Ref entry' do
          obj = { Dummy: [{ Hoge: 'Route' }] }
          expect(contains_ref(obj, ['Route'])).to be_falsey
        end

        it 'return false when template hasn\'t Ref entry with specified resource' do
          obj = { Dummy: [{ Ref: 'Hoge' }] }
          expect(contains_ref(obj, ['Route'])).to be_falsey
        end
      end

      describe '#contains_att' do
        it 'return true when template has GetAtt entry with specified resource' do
          obj = { :'Fn::GetAtt' => %w(Route Dummy) }
          expect(contains_att(obj, ['Route'])).to be_truthy
        end

        it 'return true when deep hash has GetAtt entry' do
          obj = { Dummy: { :'Fn::GetAtt' => %w(Route Dummy) } }
          expect(contains_att(obj, ['Route'])).to be_truthy
        end

        it 'return true when deep array has GetAtt entry' do
          obj = { Dummy: [{ :'Fn::GetAtt' => %w(Route Dummy) }] }
          expect(contains_att(obj, ['Route'])).to be_truthy
        end

        it 'return false when template hasn\'t Ref entry' do
          obj = { Dummy: [{ Dummy: %w(Route Dummy) }] }
          expect(contains_att(obj, ['Route'])).to be_falsey
        end

        it 'return false when template hasn\'t Ref entry with specified resource' do
          obj = { Dummy: [{ :'Fn::GetAtt' => %w(Hoge Dummy) }] }
          expect(contains_att(obj, ['Route'])).to be_falsey
        end
      end
    end
  end
end
