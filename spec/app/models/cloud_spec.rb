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
describe Cloud do
  include_context 'default_resources'

  before do
    allow_any_instance_of(Project).to receive(:create_preset_roles)

    @cloud = FactoryGirl.build(:cloud, :aws)

    allow(@cloud).to receive(:create_base_image)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @cloud.save! }.to change { Cloud.count }.by(1)
    end

    it 'create with long text' do
      @cloud.description = '*' * 256
      @cloud.save!
    end

    it 'call #create_base_image callback when cloud type is AWS' do
      expect(@cloud).to receive(:create_base_image)
      @cloud.save!
    end

    it 'doesn\'t call #create_base_image callback when cloud type is not AWS' do
      @cloud.type = 'openstack'
      @cloud.tenant_name = 'openstack tenant'
      expect(@cloud).not_to receive(:create_base_image)
      @cloud.save!
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@cloud.valid?).to be_truthy

      @cloud.type = 'openstack'
      @cloud.tenant_name = 'openstack tenant'
      expect(@cloud.valid?).to be_truthy

      @cloud.type = 'aws'
      @cloud.tenant_name = nil
      expect(@cloud.valid?).to be_truthy
    end

    it 'returns true when type is dummy' do
      @cloud.type = 'dummy'
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns false when project is unset' do
      @cloud.project = nil
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns false when name is unset' do
      @cloud.name = nil
      expect(@cloud.valid?).to be_falsey

      @cloud.name = ''
      expect(@cloud.valid?).to be_falsey
    end

    it 'return true when name is not unique in two Clouds' do
      FactoryGirl.create(:cloud, :openstack, name: 'Test', project: Project.new(name: 'sample'))
      expect(@cloud.valid?).to be_truthy
    end

    it 'returns true when name contains hyphen character' do
      @cloud.name = 'sample-name'
      expect(@cloud.valid?).to be_truthy
    end

    it 'returns false when entry_point is unset' do
      @cloud.entry_point = nil
      expect(@cloud.valid?).to be_falsey

      @cloud.entry_point = ''
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns false when key is unset' do
      @cloud.key = nil
      expect(@cloud.valid?).to be_falsey

      @cloud.key = ''
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns false when secret is unset and type isn\'t wakame-vdc' do
      @cloud.secret = nil
      expect(@cloud.valid?).to be_falsey

      @cloud.secret = ''
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns true when secret is unset and type is wakame-vdc' do
      @cloud.type = 'wakame-vdc'
      @cloud.secret = nil
      expect(@cloud.valid?).to be_truthy

      @cloud.secret = ''
      expect(@cloud.valid?).to be_truthy
    end

    it 'returns false when type is neither aws, openstack nor dummy' do
      @cloud.type = nil
      expect(@cloud.valid?).to be_falsey

      @cloud.type = ''
      expect(@cloud.valid?).to be_falsey

      @cloud.type = 'test'
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns false when type is openstack and tenant_name is blank' do
      @cloud.type = 'openstack'
      @cloud.tenant_name = ''
      expect(@cloud.valid?).to be_falsey

      @cloud.tenant_name = nil
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns false when region is not valid aws region' do
      @cloud.type = 'aws'
      @cloud.entry_point = 'ap-northeast-1a' # AvailabilityZone name is invalid.
      expect(@cloud.valid?).to be_falsey
    end
  end

  describe '#destroy(raise_error_in_use)' do
    it 'delete cloud record' do
      @cloud.save!
      expect { @cloud.destroy }.to change { Cloud.count }.by(-1)
    end

    it 'delete all base image records' do
      @cloud.base_images << FactoryGirl.build(:base_image, cloud: @cloud)
      @cloud.base_images << FactoryGirl.build(:base_image, cloud: @cloud)
      @cloud.save!

      expect(@cloud.base_images.size).to eq(2)
      expect { @cloud.destroy }.to change { BaseImage.count }.by(-2)
    end

    it 'raise error and cancel destroy when specified cloud is used in some environments' do
      allow(@cloud).to receive(:used?).and_return(true)

      expect do
        expect { @cloud.destroy }.to(raise_error('Can\'t destroy cloud that is used in some environments or blueprints.'))
      end.not_to change { Cloud.count }
    end
  end

  describe '#create_base_image' do
    before do
      allow(@cloud).to receive(:create_base_image).and_call_original
    end

    it 'set base_images when cloud type is AWS' do
      @cloud.create_base_image
      expect(@cloud.base_images.size).to eq(2)
    end

    it 'create base_images by images.yml' do
      expect { @cloud.save! }.to change { BaseImage.count }.by(2)
      expect(@cloud.base_images.map(&:source_image)).to match_array(%w(ami-76131818 ami-b18c82df))
      expect(BaseImage.all.map(&:source_image)).to match_array(%w(ami-76131818 ami-b18c82df))
      expect(BaseImage.all.map(&:platform_version)).to match_array(%w(6.7 7.2))
      expect(BaseImage.all.map(&:ssh_username)).to match_array(%w(centos centos))
    end
  end

  describe '#aws_images' do
    it 'return ami id list that corresponding to all of the Region' do
      expected_list = {
        'ap-northeast-1' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-76131818', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-b18c82df', 'ssh_username' => 'centos' }
        ],
        'ap-northeast-2' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-85925beb', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-5476b83a', 'ssh_username' => 'centos' }
        ],
        'ap-southeast-1' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-ce15dead', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-e362aa80', 'ssh_username' => 'centos' }
        ],
        'ap-southeast-2' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-2901214a', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-16d0f175', 'ssh_username' => 'centos' }
        ],
        'eu-west-1' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-3be36648', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-802c94f3', 'ssh_username' => 'centos' }
        ],
        'eu-central-1' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-650dea0a', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-8d0aeee2', 'ssh_username' => 'centos' }
        ],
        'sa-east-1' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-3c32bf50', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-5f991433', 'ssh_username' => 'centos' }
        ],
        'us-east-1' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-04f0f06e', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-7eafaa14', 'ssh_username' => 'centos' }
        ],
        'us-west-1' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-7e6a181e', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-84abd8e4', 'ssh_username' => 'centos' }
        ],
        'us-west-2' => [
          { 'platform' => 'centos', 'platform_version' => 6.7, 'source_image' => 'ami-417a9321', 'ssh_username' => 'centos' },
          { 'platform' => 'centos', 'platform_version' => 7.2, 'source_image' => 'ami-e85bb488', 'ssh_username' => 'centos' }
        ]
      }

      expect(@cloud.aws_images).to eq(expected_list)
    end
  end

  describe '#client' do
    it 'return instance of CloudConductor::Client that is initialized by cloud type' do
      client = double('client')
      expect(CloudConductor::Client).to receive(:new).with(@cloud).and_return(client)

      expect(@cloud.client).to eq(client)
    end
  end

  describe '#used?' do
    it 'return true when cloud is used by some systems' do
      expect(Candidate).to receive_message_chain(:where, :count).and_return(1)
      expect(@cloud.used?).to eq(true)
    end

    it 'return false when cloud is used by some systems' do
      expect(Candidate).to receive_message_chain(:where, :count).and_return(0)
      expect(@cloud.used?).to eq(false)
    end

    it 'return true when cloud is used by some blueprints' do
      expect(Image).to receive_message_chain(:where, :count).and_return(1)
      expect(@cloud.used?).to eq(true)
    end

    it 'return false when cloud is used by some blueprints' do
      expect(Image).to receive_message_chain(:where, :count).and_return(0)
      expect(@cloud.used?).to eq(false)
    end
  end

  describe '#raise_error_in_use' do
    it 'raise exception if cloud is using' do
      allow(Candidate).to receive_message_chain(:where, :count).and_return(1)

      expect { @cloud.raise_error_in_use }.to raise_error 'Can\'t destroy cloud that is used in some environments or blueprints.'
    end
  end

  describe '#as_json' do
    it 'mask secret column' do
      result = @cloud.as_json.with_indifferent_access
      expect(result[:name]).to eq(@cloud.name)
      expect(result[:type]).to eq(@cloud.type)
      expect(result[:entry_point]).to eq(@cloud.entry_point)
      expect(result[:key]).to eq(@cloud.key)
      expect(result[:secret]).to eq('********')
      expect(result[:tenant_name]).to eq(@cloud.tenant_name)
    end
  end

  describe '#to_json' do
    it 'call as_json' do
      expect(@cloud).to receive(:as_json)
      @cloud.to_json
    end
  end
end
