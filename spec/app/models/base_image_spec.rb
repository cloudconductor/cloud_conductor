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
    aws_images_yml = File.join(Rails.root, 'config/images.yml')
    ami_images = { 'ap-northeast-1' => 'ami-12345678' }
    allow(YAML).to receive(:load_file).with(aws_images_yml).and_return(ami_images)
    @base_image = FactoryGirl.build(:base_image, cloud: cloud)
  end

  describe '#initialize' do
    it 'set default to OS and ssh_username' do
      base_image = BaseImage.new

      expect(base_image.os).to eq('CentOS-6.5')
      expect(base_image.ssh_username).to eq('ec2-user')
    end

    it 'set specified value to OS and ssh_username' do
      base_image = BaseImage.new(os: 'dummy_os', ssh_username: 'dummy_user')

      expect(base_image.os).to eq('dummy_os')
      expect(base_image.ssh_username).to eq('dummy_user')
    end

    it 'doesn\'t set source_image if cloud type equal aws and source_image is not nil' do
      base_image = BaseImage.new(cloud: FactoryGirl.create(:cloud, :aws), source_image: 'ami-xxxxxxxx')

      expect(base_image.source_image).to eq('ami-xxxxxxxx')
    end

    it 'doesn\'t set source_image if cloud type equal openstack' do
      base_image = BaseImage.new(cloud: FactoryGirl.create(:cloud, :openstack))

      expect(base_image.source_image).to be_nil
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
      expect(@base_image.name).to eq("#{cloud.name}-#{@base_image.os}")
    end
  end

  describe '#builder' do
    let(:template_path) { File.join(Rails.root, 'config/templates.yml.erb') }

    before do
      allow(IO).to receive(:read).with(template_path).and_return <<-EOS
        aws:
          name: <%= name %>----{{user `role`}}
          access_key: <%= cloud.key %>
      EOS
    end

    it 'return builder options that is generated from templates.yml.erb' do
      result = @base_image.builder
      expect(result.keys).to match_array(%w(name access_key))
    end

    it 'update variables in template' do
      result = @base_image.builder
      expect(result[:name]).to eq("#{@base_image.name}----{{user `role`}}")
      expect(result[:access_key]).to eq(cloud.key)
    end
  end
end
