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

      describe '#apply' do
        before do
          @patch = AddNetworkInterface.new
        end

        it 'add AWS::EC2::NetworkInterface resource' do
          expect(@template[:Resources].size).to eq(3)
          result = @patch.apply @template, {}
          expect(result[:Resources].size).to eq(4)
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
      end
    end
  end
end
