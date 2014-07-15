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
    describe RemoveMultipleSubnet do
      before do
        @patch = RemoveMultipleSubnet.new

        @template = JSON.parse <<-EOS
          {
            "Resources": {
              "Subnet1A" : {
                "Type" : "AWS::EC2::Subnet",
                "Properties" : {
                  "AvailabilityZone": "ap-northeast-1a",
                  "VpcId" : { "Ref" : "VPC" },
                  "CidrBlock" : "192.168.0.0/24"
                }
              },
              "Sample": {
                "Type": "AWS::EC2::RouteTable",
                "Properties": {
                  "VpcId": { "Ref": "VPC" }
                }
              },
              "Subnet1B" : {
                "Type" : "AWS::EC2::Subnet",
                "Properties" : {
                  "AvailabilityZone": "ap-northeast-1b",
                  "VpcId" : { "Ref" : "VPC" },
                  "CidrBlock" : "192.168.1.0/24"
                }
              },
              "Subnet1C" : {
                "Type" : "AWS::EC2::Subnet",
                "Properties" : {
                  "AvailabilityZone": "ap-northeast-1c",
                  "VpcId" : { "Ref" : "VPC" },
                  "CidrBlock" : "192.168.2.0/24"
                }
              },
              "LoadBalancer" : {
                "Type" : "AWS::ElasticLoadBalancing::LoadBalancer",
                "Properties" : {
                  "AvailabilityZone": "ap-northeast-1c"
                }
              }
            }
          }
        EOS

        @template = @template.with_indifferent_access
      end

      it 'extend Patch class' do
        expect(RemoveMultipleSubnet.superclass).to eq(Patch)
      end

      describe '#need?' do
        it 'return false when template hasn\'t Resources hash' do
          expect(@patch.need?({}, {})).to be_falsey
        end

        it 'return false when template hasn\'t LoadBalancer Resource' do
          @template[:Resources].except!(:LoadBalancer)
          expect(@patch.need?(@template, {})).to be_falsey
        end

        it 'return true when template has LoadBalancer Resource' do
          expect(@patch.need?(@template, {})).to be_truthy
        end
      end

      describe '#apply' do
        it 'remove AWS::EC2::Route resource' do
          expect(@template[:Resources].size).to eq(5)
          result = @patch.apply @template, {}
          expect(result[:Resources].size).to eq(3)
        end

        it 'doesn\'t affect to first subnet' do
          original = @template[:Resources][:Subnet1A].deep_dup

          expect(@template[:Resources][:Subnet1A]).to eq(original)
          result = @patch.apply @template, {}
          expect(result[:Resources][:Subnet1A]).to eq(original)
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
