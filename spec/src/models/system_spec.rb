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

    @pattern = FactoryGirl.create(:pattern)
    @image = FactoryGirl.create(:image)
    @image.status = :created
    @pattern.images.push(@image)

    @system = System.new
    @system.name = 'Test'
    @system.pattern = @pattern
    @system.template_parameters = '{}'
    @system.parameters = '{}'
    @system.monitoring_host = nil
    @system.domain = 'example.com'

    @system.add_cloud(@cloud_aws, 1)
    @system.add_cloud(@cloud_openstack, 2)

    @client = double('client', create_stack: nil, get_stack_status: :NOT_CREATED, destroy_stack: nil)
    Cloud.any_instance.stub(:client).and_return(@client)

    CloudConductor::DNSClient.stub_chain(:new, :update)
    CloudConductor::ZabbixClient.stub_chain(:new, :register)
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
      expect(@system.valid?).to be_truthy
    end

    it 'returns false when name is unset' do
      @system.name = nil
      expect(@system.valid?).to be_falsey

      @system.name = ''
      expect(@system.valid?).to be_falsey
    end

    it 'returns false when template_parameters is invalid JSON string' do
      @system.template_parameters = '{'
      expect(@system.valid?).to be_falsey
    end

    it 'returns false when parameters is invalid JSON string' do
      @system.parameters = '{'
      expect(@system.valid?).to be_falsey
    end

    it 'returns false when clouds is empty' do
      @system.clouds.delete_all
      expect(@system.valid?).to be_falsey
    end

    it 'returns false when clouds collection has duplicate cloud' do
      @system.clouds.delete_all
      @system.clouds << @cloud_aws
      @system.clouds << @cloud_aws
      expect(@system.valid?).to be_falsey
    end

    it 'returns false when pattern status isn\'t created' do
      @image.status = :processing
      expect(@system.valid?).to be_falsey
    end
  end

  describe '#before_create' do
    before do
      @template_parameters = JSON.parse @system.template_parameters
    end

    it 'call create_stack on cloud that has highest priority' do
      @client.should_receive(:create_stack)
        .with(@system.name, @system.pattern, @template_parameters)

      @system.save!
    end

    it 'call create_stack on clouds with priority order' do
      @client.should_receive(:create_stack)
        .with(@system.name, @system.pattern, @template_parameters).ordered
        .and_raise('Dummy exception')

      @client.should_receive(:create_stack)
        .with(@system.name, @system.pattern, @template_parameters).ordered

      @system.save!
    end

    it 'update active flag on successful cloud' do
      @system.save!
      expect(@system.available_clouds.find_by_cloud_id(@cloud_openstack).active).to be_truthy
    end
  end

  describe '#enable_monitoring(before_save)' do
    before do
      @zabbix_client = double('zabbix_client', register: nil)
      CloudConductor::ZabbixClient.stub(:new).and_return(@zabbix_client)
    end

    it 'doesn\'t call ZabbixClient#register when monitoring_host is nil' do
      @zabbix_client.should_not_receive(:register)

      @system.monitoring_host = nil
      @system.save!
    end

    it 'call ZabbixClient#register when monitoring_host isn\'t nil' do
      @system.save!

      @system.monitoring_host = 'example.com'

      @zabbix_client.should_receive(:register).with(@system)

      @system.save!
    end

    it 'doesn\'t call ZabbixClient#register when monitoring_host isn\'t changed' do
      @system.save!

      @system.monitoring_host = 'example.com'
      @system.save!

      @zabbix_client.should_not_receive(:register)
      @system.monitoring_host = 'example.com'
      @system.save!
    end
  end

  describe '#update_dns(before_save)' do
    before do
      @dns_client = double('dns_client')
      CloudConductor::DNSClient.stub(:new).and_return(@dns_client)
      @dns_client.stub('update')
    end

    it 'doesn\'t call DNSClient#update when ip_address is nil' do
      @dns_client.should_not_receive(:update)

      @system.ip_address = nil
      @system.save!
    end

    it 'call Client#update when monitoring_host isn\'t nil' do
      @system.ip_address = '192.168.0.1'
      @dns_client.should_receive(:update).with(@system.domain, @system.ip_address)

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
    it 'duplicate all attributes in system without name and ip_address' do
      duplicated_system = @system.dup
      expect(duplicated_system.template_parameters).to eq(@system.template_parameters)
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

    it 'clear ip_address' do
      @system.ip_address = '192.168.0.1'
      expect(@system.dup.ip_address).to be_nil
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

  describe '#status' do
    it 'call get_stack_status on adapter that related active cloud' do
      @system.save!

      @client.should_receive(:get_stack_status).with(@system.name).and_return(:dummy)

      expect(@system.status).to eq(:dummy)
    end
  end

  describe '#outputs' do
    it 'call get_outputs on adapter that related active cloud' do
      @system.save!

      @client.should_receive(:get_outputs).with(@system.name).and_return(key: 'value')

      expect(@system.outputs).to eq(key: 'value')
    end
  end

  describe '.in_progress scope' do
    it 'returns systems without monitoring host' do
      count = System.in_progress.count

      @system.save!

      expect(System.in_progress.count).to eq(count + 1)

      @system.ip_address = '192.168.0.1'
      @system.save!

      expect(System.in_progress.count).to eq(count)
    end
  end

  describe '#destroy' do
    it 'will delete system record' do
      count = System.count
      @system.save!
      @system.destroy
      expect(System.count).to eq(count)
    end

    it 'will delete relation record on AvailableCloud' do
      count = AvailableCloud.count
      @system.save!
      expect(AvailableCloud.count).to_not eq(count)
      @system.destroy
      expect(AvailableCloud.count).to eq(count)
    end

    it 'will call destroy_stack method on current adapter' do
      @system.save!

      @client.should_receive(:destroy_stack).with(@system.name)

      @system.destroy
    end
  end

  describe '#serf' do
    it 'will fail when ip_address does not specified' do
      @system.ip_address = nil
      expect { @system.serf }.to raise_error('ip_address does not specified')
    end

    it 'return serf client when ip_address already specified' do
      @system.ip_address = '127.0.0.1'
      expect(@system.serf).to be_is_a Serf::Client
    end
  end
end
