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
      include PatchUtils

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

        it 'not add AWS::EC2::NetworkInterface resource if NetworkInterface of the property does not exist' do
          template = JSON.parse <<-EOS
            {
              "Resources": {
                "Instance": {
                  "Type" : "AWS::EC2::Instance",
                  "Properties" : {
                  }
                }
              }
            }
          EOS
          template = template.with_indifferent_access

          result = @patch.apply template, {}
          expect(result[:Resources].select(&type?('AWS::EC2::NetworkInterface'))).to be_empty
        end

        it 'not add AWS::EC2::NetworkInterface resource if NetworkInterface:NetworkInterfaceId of the property exist' do
          template = JSON.parse <<-EOS
            {
              "Resources": {
                "Instance": {
                  "Type": "AWS::EC2::Instance",
                  "Properties": {
                    "NetworkInterfaces": [{
                      "NetworkInterfaceId": {"Ref" : "NIC"},
                      "DeviceIndex": "0"
                    }]
                  }
                },
                "NIC": {
                  "Type": "AWS::EC2::NetworkInterface",
                  "Properties": {
                  }
                }
              }
            }
          EOS
          template = template.with_indifferent_access

          expect(template[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(1)
          result = @patch.apply template, {}
          expect(result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(1)
        end

        it 'add AWS::EC2::NetworkInterface resource if NetworkInterface:NetworkInterfaceId property does not exist' do
          template = JSON.parse <<-EOS
            {
              "Resources": {
                "Instance": {
                  "Type" : "AWS::EC2::Instance",
                  "Properties" : {
                    "NetworkInterfaces" : [{
                      "AssociatePublicIpAddress" : true,
                      "DeleteOnTermination" : true,
                      "Description" : "Dummy Description",
                      "DeviceIndex" : "0",
                      "GroupSet" : ["SecurityGroup"],
                      "PrivateIpAddress" : "0.0.0.0",
                      "PrivateIpAddresses" : ["0.0.0.0"],
                      "SecondaryPrivateIpAddressCount" : 1,
                      "SubnetId" : "Subnet"
                    }]
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
                "SecurityGroup" : {
                  "Type" : "AWS::EC2::SecurityGroup",
                  "Properties" : {
                  }
                }
              }
            }
          EOS
          template = template.with_indifferent_access

          expect(template[:Resources][:Instance][:Properties][:NetworkInterfaces][0].keys.size).to eq(9)
          expect(template[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(0)
          result = @patch.apply template, {}
          keys = result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys
          expect(result[:Resources][:Instance][:Properties][:NetworkInterfaces][0].keys.size).to eq(2)
          expect(result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(1)
          expect(result[:Resources][keys[0]][:Properties].keys.size).to eq(6)
          expect(result[:Resources][keys[0]][:Properties][:Description]).to eq('Dummy Description')
          expect(result[:Resources][keys[0]][:Properties][:GroupSet]).to eq(['SecurityGroup'])
          expect(result[:Resources][keys[0]][:Properties][:PrivateIpAddress]).to eq('0.0.0.0')
          expect(result[:Resources][keys[0]][:Properties][:PrivateIpAddresses]).to eq(['0.0.0.0'])
          expect(result[:Resources][keys[0]][:Properties][:SecondaryPrivateIpAddressCount]).to eq(1)
          expect(result[:Resources][keys[0]][:Properties][:SubnetId]).to eq('Subnet')
        end

        it 'add multi AWS::EC2::NetworkInterface resource if multi NetworkInterface of the properties existed' do
          template = JSON.parse <<-EOS
            {
              "Resources": {
                "Instance": {
                  "Type" : "AWS::EC2::Instance",
                  "Properties" : {
                    "NetworkInterfaces" : [{
                      "AssociatePublicIpAddress" : true,
                      "DeleteOnTermination" : true,
                      "Description" : "Dummy Description",
                      "DeviceIndex" : "0",
                      "GroupSet" : ["SecurityGroup"],
                      "PrivateIpAddress" : "0.0.0.0",
                      "PrivateIpAddresses" : ["0.0.0.0"],
                      "SecondaryPrivateIpAddressCount" : 1,
                      "SubnetId" : "Subnet"
                    },
                    {
                      "AssociatePublicIpAddress" : true,
                      "DeleteOnTermination" : true,
                      "Description" : "Dummy Description",
                      "DeviceIndex" : "0",
                      "GroupSet" : ["SecurityGroup"],
                      "PrivateIpAddress" : "0.0.0.0",
                      "PrivateIpAddresses" : ["0.0.0.0"],
                      "SecondaryPrivateIpAddressCount" : 1,
                      "SubnetId" : "Subnet"
                    }]
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
                "SecurityGroup" : {
                  "Type" : "AWS::EC2::SecurityGroup",
                  "Properties" : {
                  }
                }
              }
            }
          EOS
          template = template.with_indifferent_access

          expect(template[:Resources][:Instance][:Properties][:NetworkInterfaces][0].keys.size).to eq(9)
          expect(template[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(0)
          result = @patch.apply template, {}
          keys = result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys
          expect(result[:Resources][:Instance][:Properties][:NetworkInterfaces][0].keys.size).to eq(2)
          expect(result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(2)
          expect(result[:Resources][keys[0]][:Properties].keys.size).to eq(6)
          expect(result[:Resources][keys[0]][:Properties][:Description]).to eq('Dummy Description')
          expect(result[:Resources][keys[0]][:Properties][:GroupSet]).to eq(['SecurityGroup'])
          expect(result[:Resources][keys[0]][:Properties][:PrivateIpAddress]).to eq('0.0.0.0')
          expect(result[:Resources][keys[0]][:Properties][:PrivateIpAddresses]).to eq(['0.0.0.0'])
          expect(result[:Resources][keys[0]][:Properties][:SecondaryPrivateIpAddressCount]).to eq(1)
          expect(result[:Resources][keys[0]][:Properties][:SubnetId]).to eq('Subnet')
        end

        it 'add multi AWS::EC2::NetworkInterface resource if multi Instance existed' do
          template = JSON.parse <<-EOS
            {
              "Resources": {
                "InstanceA": {
                  "Type" : "AWS::EC2::Instance",
                  "Properties" : {
                    "NetworkInterfaces" : [{
                      "AssociatePublicIpAddress" : true,
                      "DeleteOnTermination" : true,
                      "Description" : "Dummy Description",
                      "DeviceIndex" : "0",
                      "GroupSet" : ["SecurityGroup"],
                      "PrivateIpAddress" : "0.0.0.0",
                      "PrivateIpAddresses" : ["0.0.0.0"],
                      "SecondaryPrivateIpAddressCount" : 1,
                      "SubnetId" : "Subnet"
                    }]
                  }
                },
                "InstanceB": {
                  "Type" : "AWS::EC2::Instance",
                  "Properties" : {
                    "NetworkInterfaces" : [{
                      "AssociatePublicIpAddress" : true,
                      "DeleteOnTermination" : true,
                      "Description" : "Dummy Description",
                      "DeviceIndex" : "0",
                      "GroupSet" : ["SecurityGroup"],
                      "PrivateIpAddress" : "0.0.0.0",
                      "PrivateIpAddresses" : ["0.0.0.0"],
                      "SecondaryPrivateIpAddressCount" : 1,
                      "SubnetId" : "Subnet"
                    }]
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
                "SecurityGroup" : {
                  "Type" : "AWS::EC2::SecurityGroup",
                  "Properties" : {
                  }
                }
              }
            }
          EOS
          template = template.with_indifferent_access

          expect(template[:Resources][:InstanceA][:Properties][:NetworkInterfaces][0].keys.size).to eq(9)
          expect(template[:Resources][:InstanceB][:Properties][:NetworkInterfaces][0].keys.size).to eq(9)
          expect(template[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(0)
          result = @patch.apply template, {}
          keys = result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys
          expect(result[:Resources][:InstanceA][:Properties][:NetworkInterfaces][0].keys.size).to eq(2)
          expect(result[:Resources][:InstanceB][:Properties][:NetworkInterfaces][0].keys.size).to eq(2)
          expect(result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(2)
          expect(result[:Resources][keys[0]][:Properties].keys.size).to eq(6)
          expect(result[:Resources][keys[0]][:Properties][:Description]).to eq('Dummy Description')
          expect(result[:Resources][keys[0]][:Properties][:GroupSet]).to eq(['SecurityGroup'])
          expect(result[:Resources][keys[0]][:Properties][:PrivateIpAddress]).to eq('0.0.0.0')
          expect(result[:Resources][keys[0]][:Properties][:PrivateIpAddresses]).to eq(['0.0.0.0'])
          expect(result[:Resources][keys[0]][:Properties][:SecondaryPrivateIpAddressCount]).to eq(1)
          expect(result[:Resources][keys[0]][:Properties][:SubnetId]).to eq('Subnet')
        end

        it 'add AWS::EC2::NetworkInterface resource that meets condition only' do
          template = JSON.parse <<-EOS
            {
              "Resources": {
                "InstanceA": {
                  "Type" : "AWS::EC2::Instance",
                  "Properties" : {
                    "NetworkInterfaces" : [{
                      "AssociatePublicIpAddress" : true,
                      "DeleteOnTermination" : true,
                      "Description" : "Dummy Description",
                      "DeviceIndex" : "0",
                      "GroupSet" : ["SecurityGroup"],
                      "PrivateIpAddress" : "0.0.0.0",
                      "PrivateIpAddresses" : ["0.0.0.0"],
                      "SecondaryPrivateIpAddressCount" : 1,
                      "SubnetId" : "Subnet"
                    }]
                  }
                },
                "InstanceB": {
                  "Type" : "AWS::EC2::Instance",
                  "Properties" : {
                    "NetworkInterfaces" : [{
                      "NetworkInterfaceId": {"Ref" : "NIC"},
                      "DeviceIndex": "0"
                    }]
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
                "SecurityGroup" : {
                  "Type" : "AWS::EC2::SecurityGroup",
                  "Properties" : {
                  }
                }
              }
            }
          EOS
          template = template.with_indifferent_access

          expect(template[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(0)
          result = @patch.apply template, {}
          expect(result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(1)

          expect(template[:Resources][:InstanceA][:Properties][:NetworkInterfaces][0].keys.size).to eq(9)
          expect(template[:Resources][:InstanceB][:Properties][:NetworkInterfaces][0].keys.size).to eq(2)
          expect(template[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(0)
          result = @patch.apply template, {}
          keys = result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys
          expect(result[:Resources][:InstanceA][:Properties][:NetworkInterfaces][0].keys.size).to eq(2)
          expect(result[:Resources][:InstanceB][:Properties][:NetworkInterfaces][0].keys.size).to eq(2)
          expect(result[:Resources].select(&type?('AWS::EC2::NetworkInterface')).keys.size).to eq(2)
          expect(result[:Resources][keys[0]][:Properties].keys.size).to eq(6)
          expect(result[:Resources][keys[0]][:Properties][:Description]).to eq('Dummy Description')
          expect(result[:Resources][keys[0]][:Properties][:GroupSet]).to eq(['SecurityGroup'])
          expect(result[:Resources][keys[0]][:Properties][:PrivateIpAddress]).to eq('0.0.0.0')
          expect(result[:Resources][keys[0]][:Properties][:PrivateIpAddresses]).to eq(['0.0.0.0'])
          expect(result[:Resources][keys[0]][:Properties][:SecondaryPrivateIpAddressCount]).to eq(1)
          expect(result[:Resources][keys[0]][:Properties][:SubnetId]).to eq('Subnet')
        end
      end
    end
  end
end
