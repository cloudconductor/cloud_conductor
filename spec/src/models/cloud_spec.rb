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
    @cloud.type = 'aws'
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
      expect(@cloud.valid?).to be_true

      @cloud.type = 'openstack'
      expect(@cloud.valid?).to be_true

      @cloud.type = 'aws'
      @cloud.tenant_id = nil
      expect(@cloud.valid?).to be_true
    end

    it 'returns false when name is unset' do
      @cloud.name = nil
      expect(@cloud.valid?).to be_false

      @cloud.name = ''
      expect(@cloud.valid?).to be_false
    end

    it 'returns false when key is unset' do
      @cloud.key = nil
      expect(@cloud.valid?).to be_false

      @cloud.key = ''
      expect(@cloud.valid?).to be_false
    end

    it 'returns false when secret is unset' do
      @cloud.secret = nil
      expect(@cloud.valid?).to be_false

      @cloud.secret = ''
      expect(@cloud.valid?).to be_false
    end

    it 'returns false when type is neither aws nor openstack' do
      @cloud.type = nil
      expect(@cloud.valid?).to be_false

      @cloud.type = ''
      expect(@cloud.valid?).to be_false

      @cloud.type = 'test'
      expect(@cloud.valid?).to be_false
    end

    it 'returns false when type is openstack and tenant_id is blank' do
      @cloud.type = 'openstack'
      @cloud.tenant_id = ''
      expect(@cloud.valid?).to be_false

      @cloud.tenant_id = nil
      expect(@cloud.valid?).to be_false
    end
  end
end
