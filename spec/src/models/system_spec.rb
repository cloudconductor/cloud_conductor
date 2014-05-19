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
describe System do
  before do
    @cloud_aws = FactoryGirl.create(:cloud_aws)
    @cloud_openstack = FactoryGirl.create(:cloud_openstack)

    @system = System.new
    @system.name = 'Test'
    @system.template_body = '{}'
    @system.parameters = '{}'
    @system.primary_cloud = @cloud_aws
    @system.secondary_cloud = @cloud_openstack
  end

  it 'create with valid parameters' do
    count = System.count

    @system.save!

    expect(System.count).to eq(count + 1)
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@system.valid?).to be_true
    end

    it 'returns false when name is unset' do
      @system.name = nil
      expect(@system.valid?).to be_false

      @system.name = ''
      expect(@system.valid?).to be_false
    end

    it 'returns false when unset template_body and template_url both' do
      @system.template_body = nil
      expect(@system.valid?).to be_false
    end

    it 'returns false when set template_body and template_url both' do
      @system.template_url = 'http://www.example.com/'
      expect(@system.valid?).to be_false
    end

    it 'returns true when set template_url only' do
      @system.template_body = nil
      @system.template_url = 'http://www.example.com/'
      expect(@system.valid?).to be_true
    end

    it 'returns false when template_body is invalid JSON string' do
      @system.template_body = '{'
      expect(@system.valid?).to be_false
    end

    it 'returns false when template_url is invalid URL' do
      @system.template_body = nil
      @system.template_url = 'INVALID URL'
      expect(@system.valid?).to be_false
    end

    it 'returns false when parameters is invalid JSON string' do
      @system.parameters = '{'
      expect(@system.valid?).to be_false
    end

    it 'returns false when primary cloud is unset' do
      @system.primary_cloud = nil
      expect(@system.valid?).to be_false
    end

    it 'returns false when secondary cloud is unset' do
      @system.primary_cloud = nil
      expect(@system.valid?).to be_false
    end

    it 'returns false when primary cloud equals secondary cloud' do
      @system.secondary_cloud = @system.primary_cloud
      expect(@system.valid?).to be_false
    end
  end

  describe '#before_create' do
    it 'instantiate cloud client with primary cloud adapter' do
      CloudClient::Client.should_receive(:new).and_call_original
      @system.save!
    end

    it 'call create_stack on client' do
      CloudClient::Client.any_instance.should_receive(:create_stack).with(kind_of(String), kind_of(String), kind_of(Hash))
      @system.save!
    end
  end
end
