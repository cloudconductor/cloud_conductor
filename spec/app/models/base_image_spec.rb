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
  include_context 'default_resources'

  before do
    BaseImage.ami_images = nil
    ami_images = { 'ap-northeast-1' => 'ami-12345678' }
    allow(YAML).to receive(:load_file).and_call_original
    allow(YAML).to receive(:load_file).with(BaseImage::IMAGES_FILE_PATH).and_return(ami_images)

    @base_image = BaseImage.new(cloud: cloud, os: 'dummy_os', source_image: 'dummy_image')
  end

  describe '#initialize' do
    it 'set default to OS and ssh_username' do
      base_image = BaseImage.new

      expect(base_image.os).to eq(BaseImage::DEFAULT_OS)
      expect(base_image.ssh_username).to eq(BaseImage::DEFAULT_SSH_USERNAME)
    end

    it 'set specified value to OS and ssh_username' do
      base_image = BaseImage.new(os: 'dummy_os', ssh_username: 'dummy_user')

      expect(base_image.os).to eq('dummy_os')
      expect(base_image.ssh_username).to eq('dummy_user')
    end

    it 'set source_image if cloud type equal aws and source_image is nil' do
      base_image = BaseImage.new(cloud: FactoryGirl.create(:cloud_aws))

      expect(base_image.source_image).to eq('ami-12345678')
    end

    it 'doesn\'t set source_image if cloud type equal aws and source_image is not nil' do
      base_image = BaseImage.new(cloud: FactoryGirl.create(:cloud_aws), source_image: 'ami-xxxxxxxx')

      expect(base_image.source_image).to eq('ami-xxxxxxxx')
    end

    it 'doesn\'t set source_image if cloud type equal openstack' do
      base_image = BaseImage.new(cloud: FactoryGirl.create(:cloud_openstack))

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

    it 'returns false when OS is unset' do
      @base_image.os = nil
      expect(@base_image.valid?).to be_falsey

      @base_image.os = ''
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
    it 'return string that joined cloud name and OS name with hyphen' do
      expect(@base_image.name).to eq("#{cloud.name}#{BaseImage::SPLITTER}dummy_os")
    end
  end

  describe '#builder' do
    it 'return builder options that is generated from templates.yml.erb' do
      allow(IO).to receive(:read).with(BaseImage::TEMPLATE_PATH).and_return <<-EOS
        dummy:
          name: <%= name %>----{{user `role`}}
          access_key: <%= cloud.key %>
      EOS

      result = @base_image.builder
      expect(result.keys).to match_array(%w(name access_key))
    end

    it 'update variables in template' do
      allow(IO).to receive(:read).with(BaseImage::TEMPLATE_PATH).and_return <<-EOS
        dummy:
          name: <%= name %>----{{user `role`}}
          access_key: <%= cloud.key %>
      EOS

      result = @base_image.builder
      expect(result[:name]).to eq("#{@base_image.name}----{{user `role`}}")
      expect(result[:access_key]).to eq(cloud.key)
    end
  end
end
