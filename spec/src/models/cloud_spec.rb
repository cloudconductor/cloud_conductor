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
  before do
    @cloud = Cloud.new
    @cloud.name = 'Test'
    @cloud.cloud_type = 'aws'
    @cloud.entry_point = 'ap-northeast-1'
    @cloud.key = 'TestKey'
    @cloud.secret = 'TestSecret'
    @cloud.tenant_id = 'TestTenant'
  end

  it 'create with valid parameters' do
    count = Cloud.count

    @cloud.save!

    expect(Cloud.count).to eq(count + 1)
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@cloud.valid?).to be_truthy

      @cloud.cloud_type = 'openstack'
      expect(@cloud.valid?).to be_truthy

      @cloud.cloud_type = 'aws'
      @cloud.tenant_id = nil
      expect(@cloud.valid?).to be_truthy
    end

    it 'returns true when cloud_type is dummy' do
      @cloud.cloud_type = 'dummy'
      expect(@cloud.valid?).to be_truthy
    end

    it 'returns false when name is unset' do
      @cloud.name = nil
      expect(@cloud.valid?).to be_falsey

      @cloud.name = ''
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns false when name contains hyphen character' do
      @cloud.name = 'sample-name'
      expect(@cloud.valid?).to be_falsey
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

    it 'returns false when cloud_type is neither aws, openstack nor dummy' do
      @cloud.cloud_type = nil
      expect(@cloud.valid?).to be_falsey

      @cloud.cloud_type = ''
      expect(@cloud.valid?).to be_falsey

      @cloud.cloud_type = 'test'
      expect(@cloud.valid?).to be_falsey
    end

    it 'returns false when cloud_type is openstack and tenant_id is blank' do
      @cloud.cloud_type = 'openstack'
      @cloud.tenant_id = ''
      expect(@cloud.valid?).to be_falsey

      @cloud.tenant_id = nil
      expect(@cloud.valid?).to be_falsey
    end
  end

  describe '#client' do
    it 'return instance of CloudConductor::Client that is initialized by cloud type' do
      client = double('client')
      CloudConductor::Client.should_receive(:new).with(:aws).and_return(client)

      expect(@cloud.client).to eq(client)
    end
  end

  describe '#destroy' do
    before do
      @cloud.save!
      @system = FactoryGirl.create(:system)
      @count = Cloud.count
    end

    it 'raise error and cancel destroy when specified cloud is used in some systems' do
      @system.add_cloud @cloud, 1

      expect { @cloud.destroy }.to raise_error('Can\'t destroy cloud that is used in some systems.')
      expect(Cloud.count).to eq(@count)
    end

    it 'destroy cloud when specified cloud isn\'t used by any systems' do
      @cloud.destroy
      expect(Cloud.count).to eq(@count - 1)
    end
  end
end
