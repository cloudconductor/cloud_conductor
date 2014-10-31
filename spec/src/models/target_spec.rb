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
describe Target do
  before do
    @cloud = FactoryGirl.create(:cloud_aws)
    @operating_system = FactoryGirl.create(:operating_system)

    @target = Target.new
    @target.cloud = @cloud
    @target.operating_system = @operating_system
    @target.source_image = 'dummy_image'
  end

  describe '#name' do
    it 'return string that joined cloud name and operating_system name with hyphen' do
      expect(@target.name).to eq("#{@cloud.name}-#{@operating_system.name}")
    end
  end

  describe '#to_json' do
    it 'return valid JSON that is generated from Cloud#template' do
      @target.cloud.stub(:template).and_return <<-EOS
        {
          "dummy1": "dummy_value1",
          "dummy2": "dummy_value2"
        }
      EOS

      result = JSON.parse(@target.to_json).with_indifferent_access
      expect(result.keys).to match_array(%w(dummy1 dummy2))
    end

    it 'update variables in template' do
      @target.cloud.stub(:template).and_return <<-EOS
        {
          "cloud_name": "{{cloud `name`}}",
          "operating_system_name": "{{operating_system `name`}}",
          "source_image": "{{target `source_image`}}"
        }
      EOS

      result = JSON.parse(@target.to_json).with_indifferent_access
      expect(result[:cloud_name]).to eq(@cloud.name)
      expect(result[:operating_system_name]).to eq(@operating_system.name)
      expect(result[:source_image]).to eq(@target.source_image)
    end

    it 'doesn\'t affect variables that has unrelated receiver' do
      @target.cloud.stub(:template).and_return <<-EOS
        {
          "dummy1": "{{user `name`}}",
          "dummy2": "{{env `PATH`}}",
          "dummy3": "{{isotime}}",
          "dummy4": "{{ .Name }}"
        }
      EOS

      result = JSON.parse(@target.to_json).with_indifferent_access
      expect(result[:dummy1]).to eq('{{user `name`}}')
      expect(result[:dummy2]).to eq('{{env `PATH`}}')
      expect(result[:dummy3]).to eq('{{isotime}}')
      expect(result[:dummy4]).to eq('{{ .Name }}')
    end
  end
end
