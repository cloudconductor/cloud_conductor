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
    describe AddNetworkInterface do
      before do
        @template = JSON.parse <<-EOS
          {
            "Resources": {
              "Sample": {
                "Type": "AWS::EC2::RouteTable",
                "Properties": {
                  "VpcId": { "Ref": "VPC" }
                }
              },

              "Subnet" : {
                "Type" : "AWS::EC2::Subnet",
                "Properties" : {
                  "AvailabilityZone": "ap-northeast-1a",
                  "VpcId" : { "Ref" : "VPC" },
                  "CidrBlock" : "192.168.0.0/24"
                }
              },

              "SecurityGroupA" : {
                "Type" : "AWS::EC2::SecurityGroup",
                "Properties" : {
                  "VpcId" : { "Ref" : "VPC" },
                  "GroupDescription" : "Enable SSH access via port 22",
                  "SecurityGroupIngress" : [
                    { "IpProtocol" : "tcp", "FromPort" : "22", "ToPort" : "22", "CidrIp" : { "Ref" : "SSHLocation"}},
                    { "IpProtocol" : "tcp", "FromPort" : "80", "ToPort" : "80", "CidrIp" : "0.0.0.0/0"}
                  ]
                }
              },

              "SecurityGroupB" : {
                "Type" : "AWS::EC2::SecurityGroup",
                "Properties" : {
                  "VpcId" : { "Ref" : "VPC" },
                  "GroupDescription" : "Enable SSH access via port 22",
                  "SecurityGroupIngress" : [
                    { "IpProtocol" : "tcp", "FromPort" : "22", "ToPort" : "22", "CidrIp" : { "Ref" : "SSHLocation"}},
                    { "IpProtocol" : "tcp", "FromPort" : "80", "ToPort" : "80", "CidrIp" : "0.0.0.0/0"}
                  ]
                }
              }
            }
          }
        EOS

        @template = @template.with_indifferent_access
      end

      it 'extend Patch class' do
        expect(AddNetworkInterface.superclass).to eq(Patch)
      end

      describe '#ensure' do
        it 'append Resources hash if hasn\'t it' do
          patch = RemoveRoute.new
          result = patch.ensure({}, {})
          expect(result.keys).to match_array([:Resources])
        end
      end

      describe '#apply' do
        before do
          @patch = AddNetworkInterface.new
        end

        it 'add AWS::EC2::NetworkInterface resource' do
          expect(@template[:Resources].size).to eq(4)
          expect(@template[:Resources][:NIC]).to be_nil
          result = @patch.apply @template, {}
          expect(result[:Resources].size).to eq(5)
          expect(result[:Resources][:NIC]).not_to be_nil
        end

        it 'add GroupSet property when template has SecurityGroup' do
          result = @patch.apply @template, {}
          expect(result[:Resources][:NIC][:Properties][:GroupSet]).not_to be_nil
        end

        it 'add first SecurityGroup to GroupSet property' do
          result = @patch.apply @template, {}
          expect(result[:Resources][:NIC][:Properties][:GroupSet].first[:Ref]).to eq('SecurityGroupA')
        end

        it 'doesn\'t add GroupSet property when template hasn\'t SecurityGroup' do
          @template[:Resources].except! :SecurityGroupA, :SecurityGroupB
          result = @patch.apply @template, {}
          expect(result[:Resources][:NIC][:Properties][:GroupSet]).to be_nil
        end

        it 'doesn\'t affect to first Subnet' do
          original = @template[:Resources][:Subnet].deep_dup

          expect(@template[:Resources][:Subnet]).to eq(original)
          result = @patch.apply @template, {}
          expect(result[:Resources][:Subnet]).to eq(original)
        end

        it 'doesn\'t affect to first SecurityGroup' do
          original = @template[:Resources][:SecurityGroupA].deep_dup

          expect(@template[:Resources][:SecurityGroupA]).to eq(original)
          result = @patch.apply @template, {}
          expect(result[:Resources][:SecurityGroupA]).to eq(original)
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

        it 'raise error when template hasn\'t subnet' do
          @template[:Resources].delete(:Subnet)

          expect { @patch.apply @template, {} }.to raise_error('Subnet was not found')
        end
      end
    end
  end
end
