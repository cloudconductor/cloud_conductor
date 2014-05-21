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

    @system.clouds << @cloud_aws
    @system.clouds << @cloud_openstack

    CloudConductor::Client.stub_chain(:new, :create_stack)
  end

  it 'create with valid parameters' do
    count = System.count

    @system.save!

    expect(System.count).to eq(count + 1)
  end

  it 'delete all relatioship between system and cloud' do
    expect(@system.clouds).not_to be_empty
    expect(@system.available_clouds).not_to be_empty

    @system.clouds.delete_all

    expect(@system.clouds).to be_empty
    expect(@system.available_clouds).to be_empty
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

    it 'returns false when clouds is empty' do
      @system.clouds.delete_all
      expect(@system.valid?).to be_false
    end

    it 'returns false when clouds collection has duplicate cloud' do
      @system.clouds.delete_all
      @system.clouds << @cloud_aws
      @system.clouds << @cloud_aws
      expect(@system.valid?).to be_false
    end
  end

  describe '#before_create' do
    it 'just use template_body without download when already set template_body' do
      @system.should_not_receive(:open)
      @system.save!
    end

    it 'download json from url that is specified by template_url' do
      @system.template_body = nil
      @system.template_url = 'http://example.com/'

      @system.should_receive(:open).with(@system.template_url) do
        double(:file).tap do |proxy|
          proxy.stub(:read).and_return('{}')
        end
      end

      @system.save!
    end

    it 'instantiate cloud client with primary cloud adapter' do
      CloudConductor::Client.should_receive(:new)
      @system.save!
    end

    it 'call create_stack on client' do
      CloudConductor::Client.stub(:new) do
        double('client').tap do |client|
          client.should_receive(:create_stack)
            .with(@system.name, @system.template_body, @system.parameters, @system.clouds.first.attributes)
        end
      end

      @system.save!
    end
  end
end
