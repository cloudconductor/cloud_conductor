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
    @cloud = Cloud.new
    @cloud.project = project
    @cloud.name = 'Test'
    @cloud.type = 'aws'
    @cloud.entry_point = 'ap-northeast-1'
    @cloud.key = 'TestKey'
    @cloud.secret = 'TestSecret'
    @cloud.tenant_name = 'TestTenant'
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @cloud.save! }.to change { Cloud.count }.by(1)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@cloud.valid?).to be_truthy

      @cloud.type = 'openstack'
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

    it 'returns false when secret is unset' do
      @cloud.secret = nil
      expect(@cloud.valid?).to be_falsey

      @cloud.secret = ''
      expect(@cloud.valid?).to be_falsey
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
  end

  describe '#destroy(raise_error_in_use)' do
    it 'delete cloud record' do
      @cloud.save!
      expect { @cloud.destroy }.to change { Cloud.count }.by(-1)
    end

    it 'delete all base image records' do
      cloud = FactoryGirl.create(:cloud, :openstack, project: project)
      FactoryGirl.create(:base_image, cloud: cloud)
      FactoryGirl.create(:base_image, cloud: cloud)

      expect(cloud.base_images.size).to eq(2)
      expect { cloud.destroy }.to change { BaseImage.count }.by(-2)
    end

    it 'raise error and cancel destroy when specified cloud is used in some environments' do
      allow(@cloud).to receive(:used?).and_return(true)

      expect do
        expect { @cloud.destroy }.to(raise_error('Can\'t destroy cloud that is used in some systems.'))
      end.not_to change { Cloud.count }
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
  end

  describe '#to_json' do
    it 'mask secret column' do
      result = JSON.parse(@cloud.to_json, symbolize_names: true)
      expect(result[:name]).to eq('Test')
      expect(result[:type]).to eq('aws')
      expect(result[:entry_point]).to eq('ap-northeast-1')
      expect(result[:key]).to eq('TestKey')
      expect(result[:secret]).to eq('********')
      expect(result[:tenant_name]).to eq('TestTenant')
    end
  end
end
