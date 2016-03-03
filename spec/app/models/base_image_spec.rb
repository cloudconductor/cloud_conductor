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
    allow_any_instance_of(Project).to receive(:create_preset_roles)

    @cloud = Cloud.eager_load(:project).find(cloud)
    @base_image = FactoryGirl.build(:base_image, cloud: @cloud)
  end

  describe '#initialize' do
    it 'set default to ssh_username' do
      base_image = BaseImage.new

      expect(base_image.ssh_username).to eq('centos')
    end

    it 'set specified value to platform, platform_version  and ssh_username' do
      base_image = BaseImage.new(platform: 'dummy_platform', platform_version: 'dummy_version', ssh_username: 'dummy_user')

      expect(base_image.platform).to eq('dummy_platform')
      expect(base_image.platform_version).to eq('dummy_version')
      expect(base_image.ssh_username).to eq('dummy_user')
    end

    it 'doesn\'t set source_image if cloud type equal aws and source_image is not nil' do
      base_image = BaseImage.new(cloud: FactoryGirl.build(:cloud, :aws), source_image: 'ami-xxxxxxxx')

      expect(base_image.source_image).to eq('ami-xxxxxxxx')
    end

    it 'doesn\'t set source_image if cloud type equal openstack' do
      base_image = BaseImage.new(cloud: FactoryGirl.build(:cloud, :openstack))

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

    it 'returns false when platform is unset' do
      @base_image.platform = nil
      expect(@base_image.valid?).to be_falsey

      @base_image.platform = ''
      expect(@base_image.valid?).to be_falsey
    end

    it 'returns false when platform is not family' do
      @base_image.platform = 'testOS'
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

    it 'returns false when platform is uniqueness' do
      cloud.base_images << FactoryGirl.build(:base_image, cloud: cloud, platform: 'centos', platform_version: '6.5')
      @base_image.platform = 'centos'
      @base_image.platform_version = '6.5'
      expect(@base_image.valid?).to be_falsey
    end
  end

  describe '#name' do
    it 'return string that joined cloud name, platform and platform_version with hyphen' do
      expect(@base_image.name).to eq("#{cloud.name}-#{@base_image.platform}-#{@base_image.platform_version}")
    end
  end

  describe '#builder' do
    let(:template_path) { File.join(Rails.root, 'config/template_aws.yml.erb') }

    before do
      allow(IO).to receive(:read).with(template_path).and_return <<-EOS
        name: <%= name %>----{{user `role`}}
        access_key: <%= cloud.key %>
        instance_type: <%= CloudConductor::Config.packer.aws_instance_type %>
      EOS
      allow(CloudConductor::Config).to receive_message_chain(:packer, :aws_instance_type).and_return('dummy_instance_type')
    end

    it 'return builder options that is generated from templates.yml.erb' do
      result = @base_image.builder
      expect(result.keys).to match_array(%w(name access_key instance_type))
    end

    it 'update variables in template' do
      result = @base_image.builder
      expect(result[:name]).to eq("#{@base_image.name}----{{user `role`}}")
      expect(result[:access_key]).to eq(cloud.key)
      expect(result[:instance_type]).to eq('dummy_instance_type')
    end
  end

  describe '#filtered_base_image' do
    before do
      @cloud = FactoryGirl.create(:cloud, :openstack)
      @base_image1 = FactoryGirl.create(:base_image, cloud: @cloud, platform: 'centos', platform_version: nil)
      @base_image2 = FactoryGirl.create(:base_image, cloud: @cloud, platform: 'centos', platform_version: '7.2')
      @base_image3 = FactoryGirl.create(:base_image, cloud: @cloud, platform: 'redhat', platform_version: '9.0')
      @base_image4 = FactoryGirl.create(:base_image, cloud: @cloud, platform: 'ubuntu', platform_version: '14.04')
      @base_image5 = FactoryGirl.create(:base_image, cloud: @cloud, platform: 'fedora', platform_version: '23')
    end

    it 'return usable base_image that filtered by platform and platform_version' do
      expect(BaseImage.filtered_base_image(@cloud, 'centos', '7.2')).to eq(@base_image2)
    end

    it 'return usable base_image that filtered by platform and platform_version is nil' do
      expect(BaseImage.filtered_base_image(@cloud, 'ubuntu', nil)).to eq(@base_image4)
    end

    it 'return usable base_image that filtered by platform' do
      expect(BaseImage.filtered_base_image(@cloud, 'ubuntu', '15.04')).to eq(@base_image4)
    end

    it 'return usable base_image that filtered by platform family' do
      expect(BaseImage.filtered_base_image(@cloud, 'pidora', '20')).to eq(@base_image5)
    end

    it 'return nil when usable base image does not exist' do
      expect(BaseImage.filtered_base_image(@cloud, 'windows', '10')).to be_nil
    end
  end
end
