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
    class AddNetworkInterface < Patch
      include PatchUtils

      PORTABLE_PROPERTIES = %w(Description GroupSet PrivateIpAddress PrivateIpAddresses SecondaryPrivateIpAddressCount SubnetId)
      DELETE_PROPERTIES = PORTABLE_PROPERTIES + %w(AssociatePublicIpAddress DeleteOnTermination)

      NIC_TEMPLATE = <<-EOS
        {
          "Type" : "AWS::EC2::NetworkInterface",
          "Properties" : {
          }
        }
      EOS

      def initialize
      end

      def ensure(template, _parameters)
        template[:Resources] ||= {}
        template
      end

      def apply(template, _parameters)
        template = template.deep_dup

        template[:Resources].select(&type?('AWS::EC2::Instance')).map do |_key, instance|
          next if instance[:Properties].nil? || instance[:Properties][:NetworkInterfaces].nil?
          instance[:Properties][:NetworkInterfaces].each do |network_interface|
            next unless network_interface[:NetworkInterfaceId].nil?

            nic = JSON.parse(NIC_TEMPLATE).with_indifferent_access
            nic[:Properties].update network_interface.slice(*PORTABLE_PROPERTIES)
            network_interface.except!(*DELETE_PROPERTIES)

            key = SecureRandom.uuid
            template[:Resources].update(key => nic)
            network_interface.update(NetworkInterfaceId: { Ref: key })
          end
        end

        template
      end
    end
  end
end
