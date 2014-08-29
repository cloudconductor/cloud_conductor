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
    describe RenamePrimaryPrivateIpAddress do
      before do
        @template = JSON.parse <<-EOS
          {
            "dummy1": {"Fn::GetAtt": ["WebNetworkInterface", "PrimaryPrivateIpAddress"]},
            "Resources": {
              "dummy2": {"Fn::GetAtt": ["WebNetworkInterface", "PrimaryPrivateIpAddress"]},
              "dummy3": [{"Fn::GetAtt": ["WebNetworkInterface", "PrimaryPrivateIpAddress"]}],
              "dummy4": {
                "Fn::Base64": {
                  "Fn::Join": ["", [{"Fn::GetAtt": ["WebNetworkInterface", "PrimaryPrivateIpAddress"]}]]
                }
              },
              "dummy5": "PrimaryPrivateIpAddress"
            }
          }
        EOS

        @template = @template.with_indifferent_access
      end

      it 'extend Patch class' do
        expect(RenamePrimaryPrivateIpAddress.superclass).to eq(Patch)
      end

      describe '#apply' do
        before do
          @patch = RenamePrimaryPrivateIpAddress.new
        end

        it 'change PrimaryPrivateIpAddress to PrivateIpAddress' do
          expect(@template[:dummy1]['Fn::GetAtt'].last).to eq('PrimaryPrivateIpAddress')
          result = @patch.apply @template, {}
          expect(result[:dummy1]['Fn::GetAtt'].last).to eq('PrivateIpAddress')
        end

        it 'change PrimaryPrivateIpAddress to PrivateIpAddress in type of hash' do
          expect(@template[:Resources][:dummy2]['Fn::GetAtt'].last).to eq('PrimaryPrivateIpAddress')
          result = @patch.apply @template, {}
          expect(result[:Resources][:dummy2]['Fn::GetAtt'].last).to eq('PrivateIpAddress')
        end

        it 'change PrimaryPrivateIpAddress to PrivateIpAddress in type of array' do
          expect(@template[:Resources][:dummy3].first['Fn::GetAtt'].last).to eq('PrimaryPrivateIpAddress')
          result = @patch.apply @template, {}
          expect(result[:Resources][:dummy3].first['Fn::GetAtt'].last).to eq('PrivateIpAddress')
        end

        it 'change PrimaryPrivateIpAddress to PrivateIpAddress in mixed type of array and hash' do
          expect(@template[:Resources][:dummy4]['Fn::Base64']['Fn::Join'][1][0]['Fn::GetAtt'].last).to eq('PrimaryPrivateIpAddress')
          result = @patch.apply @template, {}
          expect(result[:Resources][:dummy4]['Fn::Base64']['Fn::Join'][1][0]['Fn::GetAtt'].last).to eq('PrivateIpAddress')
        end

        it 'doesn\'t change PrimaryPrivateIpAddress that isn\'t type of array or hash' do
          expect(@template[:Resources][:dummy5]).to eq('PrimaryPrivateIpAddress')
          result = @patch.apply @template, {}
          expect(result[:Resources][:dummy5]).to eq('PrimaryPrivateIpAddress')
        end
      end
    end
  end
end
