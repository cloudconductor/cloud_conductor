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
  module Converters
    describe OpenStackConverter do
      before do
        @converter = OpenStackConverter.new
      end

      def load_json(path)
        features_path = File.expand_path('../../../features/', File.dirname(__FILE__))
        json_path = File.expand_path(path, features_path)

        json = JSON.load(File.open(json_path))
        json.with_indifferent_access
      end

      it 'extend Patch class' do
        expect(OpenStackConverter.superclass).to eq(Converter)
      end

      describe '#convert' do
        it 'apply patches that belong to OpenStackConverter' do
          expect_patches = []
          expect_patches << Patches::RemoveRoute
          expect_patches << Patches::RemoveMultipleSubnet
          expect_patches << Patches::AddIAMUser
          expect_patches << Patches::AddIAMAccessKey
          expect_patches << Patches::AddCFNCredentials

          expect_patches.each do |patch_class|
            patch_class.any_instance.should_receive(:need?).and_return(true)
            patch_class.any_instance.should_receive(:apply).and_return({})
          end

          @converter.convert({}, {})
        end
      end

      describe 'loadbalancer.json' do
        before do
          @template = load_json 'aws/loadbalancer.json'
          @answer = load_json 'open_stack/loadbalancer.json'
        end

        it 'convert from AWS template to OpenStack template' do
          _result = @converter.convert(@template, {})

          # For debug
          # puts _result.to_json
          # expect(_result).to eq(@answer)
        end
      end

      describe 'simple_instance.json' do
        before do
          @template = load_json 'aws/simple_instance.json'
          @answer = load_json 'open_stack/simple_instance.json'
        end

        it 'convert from AWS template to OpenStack template' do
          _result = @converter.convert(@template, {})
          # expect(result).to eq(@answer)
        end
      end
    end
  end
end
