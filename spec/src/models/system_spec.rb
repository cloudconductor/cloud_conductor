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
    @system.monitoring_host = nil

    @system.add_cloud(@cloud_aws, 1)
    @system.add_cloud(@cloud_openstack, 2)

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

    it 'set template_body with downloaded json' do
      @system.template_body = nil
      @system.template_url = 'http://example.com/'

      dummy_json = '{ "dummy" : "data"}'
      @system.stub_chain(:open, :read).and_return(dummy_json)
      @system.save!

      expect(@system.template_body).to eq(dummy_json)
      expect(@system.template_url).to be_nil
    end

    it 'instantiate cloud client with primary cloud adapter' do
      CloudConductor::Client.should_receive(:new)
      @system.save!
    end

    it 'call create_stack on cloud that has highest priority' do
      CloudConductor::Client.stub(:new) do
        double('client').tap do |client|
          client.should_receive(:create_stack)
            .with(@system.name, @system.template_body, @system.parameters, @cloud_openstack.attributes)
        end
      end

      @system.save!
    end

    it 'call create_stack on clouds with priority order' do
      client = double('client')
      client.should_receive(:create_stack)
        .with(@system.name, @system.template_body, @system.parameters, @cloud_openstack.attributes).ordered
        .and_raise('Dummy exception')

      client.should_receive(:create_stack)
        .with(@system.name, @system.template_body, @system.parameters, @cloud_aws.attributes).ordered

      CloudConductor::Client.stub(:new).and_return(client)

      @system.save!
    end

    it 'update active flag on successful cloud' do
      @system.save!
      expect(@system.available_clouds.find_by_cloud_id(@cloud_openstack).active).to be_true
    end
  end

  describe '#before_save' do
    before do
      @client = double('client')
      CloudConductor::Client.stub(:new).and_return(@client)
      @client.stub('create_stack')
    end

    it 'doesn\'t call Client#enable_monitoring when monitoring_host is nil' do
      @client.should_not_receive(:enable_monitoring)

      @system.monitoring_host = nil
      @system.save!
    end

    it 'call Client#enable_monitoring when monitoring_host isn\'t nil' do
      @system.monitoring_host = 'example.com'

      @client.should_receive(:enable_monitoring)
        .with(@system.name, hash_including(system_id: @system.id, target_host: @system.monitoring_host))

      @system.save!
    end
  end

  describe '#add_cloud' do
    it 'build relationship between system and specified cloud via AvailableCloud' do
      @system.clouds.delete_all
      expect(@system.clouds).to be_empty
      expect(@system.available_clouds).to be_empty

      @system.add_cloud(@cloud_aws, 45)
      @system.add_cloud(@cloud_openstack, 32)

      expect(@system.clouds).to eq([@cloud_aws, @cloud_openstack])
      expect(@system.available_clouds.map(&:priority)).to eq([45, 32])
    end
  end

  describe '#dup' do
    it 'duplicate all attributes in system without name' do
      duplicated_system = @system.dup
      expect(duplicated_system.template_body).to eq(@system.template_body)
      expect(duplicated_system.template_url).to eq(@system.template_url)
      expect(duplicated_system.parameters).to eq(@system.parameters)
    end

    it 're-numbering name attribute to avoid unique constraint' do
      duplicated_system = @system.dup
      expect(duplicated_system.name).not_to eq(@system.name)
    end

    it 'add \'_1\' suffix to original name' do
      @system.name = 'test'
      expect(@system.dup.name).to eq('test_1')
    end

    it 'change number suffix that is incremented from original suffix' do
      @system.name = 'test_23'
      expect(@system.dup.name).to eq('test_24')
    end

    it 'duplicated associated clouds' do
      duplicated_system = @system.dup
      expect(duplicated_system.clouds).to eq(@system.clouds)

      original_clouds = @system.available_clouds
      duplicated_clouds = duplicated_system.available_clouds
      expect(duplicated_clouds.map(&:cloud)).to match_array(original_clouds.map(&:cloud))
      expect(duplicated_clouds.map(&:priority)).to match_array(original_clouds.map(&:priority))
    end
  end

  describe '#available_clouds.active' do
    it 'return cloud that has active flag' do
      @system.save!

      expect(@system.available_clouds.active).to eq(@cloud_openstack)
    end
  end
end
