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
describe BaseImage do
  before do
    BaseImage.images = nil
    images = { 'ap-northeast-1' => 'ami-12345678' }
    allow(YAML).to receive(:load_file).with(BaseImage::IMAGES_FILE_PATH).and_return(images)

    @cloud = FactoryGirl.create(:cloud_aws)
    @operating_system = FactoryGirl.create(:operating_system)
    @base_image = BaseImage.new
    @base_image.cloud = @cloud
    @base_image.operating_system = @operating_system
    @base_image.source_image = 'dummy_image'
  end

  describe 'after_initialize' do
    it 'set default_value to operating_system and ssh_username' do
      base_image = BaseImage.new(cloud: @cloud)

      expect(base_image.operating_system).to eq(@operating_system)
      expect(base_image.ssh_username).to eq('ec2-user')
    end

    it 'set user value to operating_system and ssh_username' do
      operating_system = FactoryGirl.create(:operating_system)
      base_image = BaseImage.new(cloud: @cloud, operating_system: operating_system, ssh_username: 'dummy_user')

      expect(base_image.operating_system).to eq(operating_system)
      expect(base_image.ssh_username).to eq('dummy_user')
    end

    it 'set source_image if cloud type equal aws and source_image is nil' do
      base_image = BaseImage.new(cloud: @cloud)

      expect(base_image.source_image).to eq('ami-12345678')
    end

    it 'not set source_image if cloud type equal aws and source_image is not nil' do
      base_image = BaseImage.new(cloud: @cloud, source_image: 'ami-xxxxxxxx')

      expect(base_image.source_image).to eq('ami-xxxxxxxx')
    end

    it 'not set source_image if cloud type equal openstack' do
      cloud = FactoryGirl.create(:cloud_openstack)
      base_image = BaseImage.new(cloud: cloud, source_image: 'dummy_source_image')

      expect(base_image.source_image).to eq('dummy_source_image')
    end

    it 'call YAML.load_file only once' do
      expect(YAML).to receive(:load_file).once

      BaseImage.images = nil
      BaseImage.new(cloud: @cloud)
      BaseImage.new(cloud: @cloud)
    end
  end

  describe '#name' do
    it 'return string that joined cloud name and operating_system name with hyphen' do
      expect(@base_image.name).to eq("#{@cloud.name}#{BaseImage::SPLITTER}#{@operating_system.name}")
    end
  end

  describe '#to_json' do
    it 'return valid JSON that is generated from Cloud#template' do
      allow(@base_image.cloud).to receive(:template).and_return <<-EOS
        {
          "dummy1": "dummy_value1",
          "dummy2": "dummy_value2"
        }
      EOS

      result = JSON.parse(@base_image.to_json).with_indifferent_access
      expect(result.keys).to match_array(%w(dummy1 dummy2))
    end

    it 'update variables in template' do
      allow(@base_image.cloud).to receive(:template).and_return <<-EOS
        {
          "cloud_name": "{{cloud `name`}}",
          "operating_system_name": "{{operating_system `name`}}",
          "source_image": "{{base_image `source_image`}}"
        }
      EOS

      result = JSON.parse(@base_image.to_json).with_indifferent_access
      expect(result[:cloud_name]).to eq(@cloud.name)
      expect(result[:operating_system_name]).to eq(@operating_system.name)
      expect(result[:source_image]).to eq(@base_image.source_image)
    end

    it 'doesn\'t affect variables that has unrelated receiver' do
      allow(@base_image.cloud).to receive(:template).and_return <<-EOS
        {
          "dummy1": "{{user `name`}}",
          "dummy2": "{{env `PATH`}}",
          "dummy3": "{{isotime}}",
          "dummy4": "{{ .Name }}"
        }
      EOS

      result = JSON.parse(@base_image.to_json).with_indifferent_access
      expect(result[:dummy1]).to eq('{{user `name`}}')
      expect(result[:dummy2]).to eq('{{env `PATH`}}')
      expect(result[:dummy3]).to eq('{{isotime}}')
      expect(result[:dummy4]).to eq('{{ .Name }}')
    end
  end
end
