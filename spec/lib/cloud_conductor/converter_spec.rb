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
  describe Converter do
    before do
      @converter = CloudConductor::Converter.new
      @template_json = <<-EOS
      {
        "Resources": {
          "TestServer" : {
            "Type" : "AWS::EC2::Instance",
            "Metadata" : {
              "Role" : "test",
              "Frontend": "true"
            },
            "Properties" : {
              "NetworkInterfaces" : [{
                 "DeviceIndex" : "0",
                 "NetworkInterfaceId" : { "Ref" : "TestNetworkInterface" }
              }]
            }
          },
          "DummyServer" : {
            "Type" : "AWS::EC2::Instance",
            "Metadata" : {
              "Role" : "dummy"
            },
            "Properties" : {
              "NetworkInterfaces" : [{
                 "DeviceIndex" : "0",
                 "NetworkInterfaceId" : { "Ref" : "DummyNetworkInterface" }
              }]
            }
          },
          "TestNetworkInterface" : {
            "Type" : "AWS::EC2::NetworkInterface",
            "Properties" : {}
          },
          "DummyNetworkInterface" : {
            "Type" : "AWS::EC2::NetworkInterface",
            "Properties" : {}
          }
        },
        "OutPuts": {
          "DummyOutput" : {
            "Value" : "DummyValue",
            "Description" : "Dummy Output"
          }
        }
      }
      EOS
    end

    describe '#type?' do
      it 'return lambda' do
        is_sample = @converter.type?('Sample')
        expect(is_sample.class).to eq(Proc)
        expect(is_sample.lambda?).to be_truthy
      end

      it 'return true when resource has Sample type' do
        is_sample = @converter.type?('Sample')
        resource = { Type: 'Sample' }
        expect(is_sample.call('Key', resource)).to be_truthy
      end

      it 'return false when resource hasn\'t Sample type' do
        is_sample = @converter.type?('Sample')
        resource = { Type: 'Test' }
        expect(is_sample.call('Key', resource)).to be_falsey
      end
    end

    describe '#update_cluster_addresses' do
      it 'return duplicated template' do
        template_json = @template_json.dup
        template = JSON.parse(@converter.update_cluster_addresses(template_json)).with_indifferent_access

        expected_cluster_addresses = { 'Fn::Join' => [',', [{ 'Fn::GetAtt' => %w(TestNetworkInterface PrimaryPrivateIpAddress) }]] }
        expect(template[:Resources][:TestServer][:Metadata][:ClusterAddresses]).to eq(expected_cluster_addresses)
        expect(template[:Resources][:DummyServer][:Metadata][:ClusterAddresses]).to eq(expected_cluster_addresses)
        expect(template[:Outputs][:ClusterAddresses][:Value]).to eq(expected_cluster_addresses)
      end
    end

    describe '#cluster_addresses' do
      it 'return cluster addresses for string format' do
        template_json = @template_json.dup
        template = JSON.parse(@converter.update_cluster_addresses(template_json)).with_indifferent_access
        instances = template[:Resources].select(&@converter.type?('AWS::EC2::Instance'))

        expected_cluster_addresses = @converter.send(:cluster_addresses, instances)
        expect(expected_cluster_addresses).to eq('Fn::Join' => [',', [{ 'Fn::GetAtt' => %w(TestNetworkInterface PrimaryPrivateIpAddress) }]])
      end
    end
  end
end
