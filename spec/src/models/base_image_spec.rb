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
    BaseImage.ami_images = nil
    ami_images = { 'ap-northeast-1' => 'ami-12345678' }
    allow(YAML).to receive(:load_file).and_call_original
    allow(YAML).to receive(:load_file).with(BaseImage::IMAGES_FILE_PATH).and_return(ami_images)

    @cloud_aws = FactoryGirl.create(:cloud_aws)
    @base_image = BaseImage.new(cloud: @cloud_aws, operating_system: 'dummy_os')
  end

  describe '#initialize' do
    it 'set default to operating_system and ssh_username' do
      base_image = BaseImage.new

      expect(base_image.operating_system).to eq(BaseImage::DEFAULT_OPERATING_SYSTEM)
      expect(base_image.ssh_username).to eq(BaseImage::DEFAULT_SSH_USERNAME)
    end

    it 'set specified value to operating_system and ssh_username' do
      base_image = BaseImage.new(operating_system: 'dummy_os', ssh_username: 'dummy_user')

      expect(base_image.operating_system).to eq('dummy_os')
      expect(base_image.ssh_username).to eq('dummy_user')
    end

    it 'set source_image if cloud type equal aws and source_image is nil' do
      base_image = BaseImage.new(cloud: @cloud_aws)

      expect(base_image.source_image).to eq('ami-12345678')
    end

    it 'doesn\'t set source_image if cloud type equal aws and source_image is not nil' do
      base_image = BaseImage.new(cloud: @cloud_aws, source_image: 'ami-xxxxxxxx')

      expect(base_image.source_image).to eq('ami-xxxxxxxx')
    end

    it 'doesn\'t set source_image if cloud type equal openstack' do
      cloud_openstack = FactoryGirl.create(:cloud_openstack)
      base_image = BaseImage.new(cloud: cloud_openstack)

      expect(base_image.source_image).to be_nil
    end

    it 'call YAML.load_file only once' do
      expect(YAML).to receive(:load_file).once

      BaseImage.ami_images = nil
      BaseImage.new
      BaseImage.new
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@base_image.valid?).to be_truthy
    end

    it 'returns false when cloud is unset' do
      @base_image.cloud = nil
      expect(@base_image.valid?).to be_falsey
    end

    it 'returns false when operating_system is unset' do
      @base_image.operating_system = nil
      expect(@base_image.valid?).to be_falsey

      @base_image.operating_system = ''
      expect(@base_image.valid?).to be_falsey
    end

    it 'returns false when source_image is unset' do
      @base_image.source_image = nil
      expect(@base_image.valid?).to be_falsey

      @base_image.source_image = ''
      expect(@base_image.valid?).to be_falsey
    end

    it 'returns false when ssh_username is unset' do
      @base_image.ssh_username = nil
      expect(@base_image.valid?).to be_falsey

      @base_image.ssh_username = ''
      expect(@base_image.valid?).to be_falsey
    end
  end

  describe '#name' do
    it 'return string that joined cloud name and operating_system name with hyphen' do
      expect(@base_image.name).to eq("#{@cloud_aws.name}#{BaseImage::SPLITTER}dummy_os")
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
          "operating_system_name": "{{base_image `operating_system`}}",
          "source_image": "{{base_image `source_image`}}"
        }
      EOS

      result = JSON.parse(@base_image.to_json).with_indifferent_access
      expect(result[:cloud_name]).to eq(@cloud_aws.name)
      expect(result[:operating_system_name]).to eq('dummy_os')
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
