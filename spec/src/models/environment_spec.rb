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
describe Environment do
  before do
    @cloud_aws = FactoryGirl.create(:cloud_aws)
    @cloud_openstack = FactoryGirl.create(:cloud_openstack)

    pattern = FactoryGirl.build(:pattern)

    @system = System.new
    @system.name = 'Test'
    @system.monitoring_host = nil
    @system.domain = 'example.com'

    @system.add_cloud(@cloud_aws, 1)
    @system.add_cloud(@cloud_openstack, 2)

    allow(CloudConductor::DNSClient).to receive_message_chain(:new, :update)
    allow(CloudConductor::ZabbixClient).to receive_message_chain(:new, :register)

    @system.applications << FactoryGirl.build(:application, system: @system)
    @system.applications << FactoryGirl.build(:application, system: @system)
    @system.applications.first.histories << FactoryGirl.build(:application_history)
    @system.applications.first.histories << FactoryGirl.build(:application_history)

    @system.stacks << FactoryGirl.build(:stack, status: :PENDING, system: @system, pattern: pattern, cloud: @cloud_aws)
    @system.stacks << FactoryGirl.build(:stack, status: :PENDING, system: @system, pattern: pattern, cloud: @cloud_aws)

    Stack.skip_callback :destroy, :before, :destroy_stack
    ApplicationHistory.skip_callback :save, :before, :consul_request
  end

  after do
    Stack.set_callback :destroy, :before, :destroy_stack, unless: -> { pending? }
    ApplicationHistory.set_callback :save, :before, :consul_request, if: -> { !deployed? && application.system.ip_address }
  end

  it 'create with valid parameters' do
    count = System.count

    @system.save!

    expect(System.count).to eq(count + 1)
  end

  it 'delete all relatioship between system and cloud' do
    expect(@system.clouds).not_to be_empty
    expect(@system.candidates).not_to be_empty

    @system.clouds.delete_all

    expect(@system.clouds).to be_empty
    expect(@system.candidates).to be_empty
  end

  it 'delete system that has multiple stacks' do
    threads = Thread.list

    @system.stacks.each do |stack|
      stack.status = :CREATE_COMPLETE
      stack.save!
    end
    @system.save!
    @system.stacks.last.pattern = FactoryGirl.build(:pattern, type: :optional)

    @system.destroy

    (Thread.list - threads).each(&:join)
  end

  describe '#initialize' do
    it 'set empty JSON to template_parameters' do
      expect(@system.template_parameters).to eq('{}')
    end

    it 'set PENDING status' do
      expect(@system.status).to eq(:PENDING)
    end
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
  end

  describe '#enable_monitoring(before_save)' do
    before do
      @zabbix_client = double('zabbix_client', register: nil)
      allow(CloudConductor::ZabbixClient).to receive(:new).and_return(@zabbix_client)
    end

    it 'doesn\'t call ZabbixClient#register when monitoring_host is nil' do
      expect(@zabbix_client).not_to receive(:register)

      @system.monitoring_host = nil
      @system.save!
    end

    it 'call ZabbixClient#register when monitoring_host isn\'t nil' do
      @system.save!

      @system.monitoring_host = 'example.com'

      expect(@zabbix_client).to receive(:register).with(@system)

      @system.save!
    end

    it 'doesn\'t call ZabbixClient#register when monitoring_host isn\'t changed' do
      @system.save!

      @system.monitoring_host = 'example.com'
      @system.save!

      expect(@zabbix_client).not_to receive(:register)
      @system.monitoring_host = 'example.com'
      @system.save!
    end
  end

  describe '#update_dns(before_save)' do
    before do
      @dns_client = double('dns_client')
      allow(CloudConductor::DNSClient).to receive(:new).and_return(@dns_client)
      allow(@dns_client).to receive('update')
    end

    it 'doesn\'t call DNSClient#update when ip_address is nil' do
      expect(@dns_client).not_to receive(:update)

      @system.ip_address = nil
      @system.save!
    end

    it 'call Client#update when monitoring_host isn\'t nil' do
      @system.ip_address = '192.168.0.1'
      expect(@dns_client).to receive(:update).with(@system.domain, @system.ip_address)

      @system.save!
    end
  end

  describe '#add_cloud' do
    it 'build relationship between system and specified cloud via Candidate' do
      @system.clouds.delete_all
      expect(@system.clouds).to be_empty
      expect(@system.candidates).to be_empty

      @system.add_cloud(@cloud_aws, 45)
      @system.add_cloud(@cloud_openstack, 32)

      expect(@system.clouds).to eq([@cloud_aws, @cloud_openstack])
      expect(@system.candidates.map(&:priority)).to eq([45, 32])
    end
  end

  describe '#dup' do
    it 'duplicate all attributes in system without name, ip_address and monitoring_host' do
      duplicated_system = @system.dup
      expect(duplicated_system.domain).to eq(@system.domain)
    end

    it 'duplicate name with uuid to avoid unique constraint' do
      duplicated_system = @system.dup
      expect(duplicated_system.name).not_to eq(@system.name)
      expect(duplicated_system.name).to match(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end

    it 'clear ip_address' do
      @system.ip_address = '192.168.0.1'
      expect(@system.dup.ip_address).to be_nil
    end

    it 'clear monitoring_host' do
      @system.monitoring_host = 'example.com'
      expect(@system.dup.monitoring_host).to be_nil
    end

    it 'clear template_parameters' do
      @system.template_parameters = '{"SubnetId": "123456"}'
      expect(@system.dup.template_parameters).to eq('{}')
    end

    it 'duplicated associated clouds' do
      duplicated_system = @system.dup
      expect(duplicated_system.clouds).to eq(@system.clouds)

      original_clouds = @system.candidates
      duplicated_clouds = duplicated_system.candidates
      expect(duplicated_clouds.map(&:cloud)).to match_array(original_clouds.map(&:cloud))
      expect(duplicated_clouds.map(&:priority)).to match_array(original_clouds.map(&:priority))
    end

    it 'duplicate application without save' do
      applications = @system.dup.applications
      expect(applications.size).to eq(@system.applications.size)
      expect(applications).to be_all(&:new_record?)
    end

    it 'duplicate application_history without save' do
      histories = @system.dup.applications.first.histories
      expect(histories.size).to eq(@system.applications.first.histories.size)
      expect(histories).to be_all(&:new_record?)
    end

    it 'duplicate stacks without save' do
      stacks = @system.dup.stacks
      expect(stacks.size).to eq(@system.stacks.size)
      expect(stacks).to be_all(&:new_record?)
    end
  end

  describe '#destroy' do
    before do
      System.skip_callback :destroy, :before, :destroy_stacks
    end

    after do
      System.set_callback :destroy, :before, :destroy_stacks, unless: -> { stacks.empty? }
    end

    it 'will delete system record' do
      count = System.count
      @system.save!
      @system.destroy
      expect(System.count).to eq(count)
    end

    it 'will delete relation record on Candidate' do
      count = Candidate.count
      @system.save!
      expect(Candidate.count).to_not eq(count)
      @system.destroy
      expect(Candidate.count).to eq(count)
    end

    it 'destroy all applications in target system' do
      @system.save!

      application_count = Application.count
      history_count = ApplicationHistory.count

      @system.destroy

      expect(Application.count).to eq(application_count - 2)
      expect(ApplicationHistory.count).to eq(history_count - 2)
    end
  end

  describe '#consul' do
    it 'will fail when ip_address does not specified' do
      @system.ip_address = nil
      expect { @system.consul }.to raise_error('ip_address does not specified')
    end

    it 'return consul client when ip_address already specified' do
      @system.ip_address = '127.0.0.1'
      expect(@system.consul).to be_is_a Consul::Client
    end
  end

  describe '#event' do
    it 'will fail when ip_address does not specified' do
      @system.ip_address = nil
      expect { @system.event }.to raise_error('ip_address does not specified')
    end

    it 'return event client when ip_address already specified' do
      @system.ip_address = '127.0.0.1'
      expect(@system.event).to be_is_a CloudConductor::Event
    end
  end

  describe '#as_json' do
    before do
      @system.id = 1
      @system.monitoring_host = 'example.com'
      @system.ip_address = '127.0.0.1'
      allow(@system).to receive(:status).and_return(:PROGRESS)
    end

    it 'return attributes as json format' do
      json = @system.as_json
      expect(json['id']).to eq(@system.id)
      expect(json['name']).to eq(@system.name)
      expect(json['monitoring_host']).to eq(@system.monitoring_host)
      expect(json['ip_address']).to eq(@system.ip_address)
      expect(json['domain']).to eq(@system.domain)
      expect(json['template_parameters']).to eq(@system.template_parameters)
      expect(json['status']).to eq(@system.status)
    end
  end

  describe '#destroy_stacks' do
    before do
      pattern1 = FactoryGirl.build(:pattern, type: :optional)
      pattern2 = FactoryGirl.build(:pattern, type: :platform)
      pattern3 = FactoryGirl.build(:pattern, type: :optional)

      @system.stacks.delete_all
      @system.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, system: @system, pattern: pattern1, cloud: @cloud_aws)
      @system.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, system: @system, pattern: pattern2, cloud: @cloud_aws)
      @system.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, system: @system, pattern: pattern3, cloud: @cloud_aws)

      @system.save!

      @system.stacks.each { |stack| allow(stack).to receive(:exist?).and_return true }

      allow(Thread).to receive(:new).and_yield

      @client = double(:client, destroy_stack: nil, get_stack_status: :DELETE_COMPLETE)
      allow(@cloud_aws).to receive(:client).and_return(@client)

      allow(@system).to receive(:sleep)

      original_timeout = Timeout.method(:timeout)
      allow(Timeout).to receive(:timeout) do |_, &block|
        original_timeout.call(0.1, &block)
      end
    end

    it 'call #destroy_stacks when before destroy' do
      expect(@system).to receive(:destroy_stacks)
      @system.destroy
    end

    it 'doesn\'t call #destroy_stacks when stacks are empty' do
      expect(@system).not_to receive(:destroy_stacks)

      @system.stacks.delete_all
      @system.destroy
    end

    it 'destroy all stacks of system' do
      expect(@system.stacks).not_to be_empty
      @system.destroy_stacks
      expect(@system.stacks).to be_empty
    end

    it 'create other thread to destroy stacks use their dependencies' do
      expect(Thread).to receive(:new).and_yield
      @system.destroy_stacks
    end

    it 'destroy optional patterns before platform' do
      expect(@system.stacks[0]).to receive(:destroy).ordered
      expect(@system.stacks[2]).to receive(:destroy).ordered
      expect(@system.stacks[1]).to receive(:destroy).ordered

      @system.destroy_stacks
    end

    it 'doesn\'t destroy platform pattern until timeout if optional pattern can\'t destroy' do
      allow(@client).to receive(:get_stack_status).and_return(:DELETE_IN_PROGRESS)

      expect(@system).to receive(:sleep).once.ordered
      expect(@system.stacks[0]).to receive(:destroy).ordered
      expect(@system.stacks[2]).to receive(:destroy).ordered
      expect(@system).to receive(:sleep).at_least(:once).ordered
      expect(@system.stacks[1]).to receive(:destroy).ordered

      @system.destroy_stacks
    end

    it 'wait and destroy platform pattern when destroyed all optional patterns' do
      allow(@client).to receive(:get_stack_status).and_return(:DELETE_IN_PROGRESS, :DELETE_COMPLETE)

      expect(@system).to receive(:sleep).once.ordered
      expect(@system.stacks[0]).to receive(:destroy).ordered
      expect(@system.stacks[2]).to receive(:destroy).ordered
      expect(@system).to receive(:sleep).once.ordered
      expect(@system.stacks[1]).to receive(:destroy).ordered

      @system.destroy_stacks
    end

    it 'wait and destroy platform pattern when failed to destroyed all optional patterns' do
      allow(@client).to receive(:get_stack_status).and_return(:DELETE_IN_PROGRESS, :DELETE_FAILED)

      expect(@system).to receive(:sleep).once.ordered
      expect(@system.stacks[0]).to receive(:destroy).ordered
      expect(@system.stacks[2]).to receive(:destroy).ordered
      expect(@system).to receive(:sleep).once.ordered
      expect(@system.stacks[1]).to receive(:destroy).ordered

      @system.destroy_stacks
    end

    it 'wait and destroy platform pattern when a part of stacks are already deleted' do
      allow(@client).to receive(:get_stack_status).with(@system.stacks[0].name).and_return(:DELETE_IN_PROGRESS, :DELETE_COMPLETE)
      allow(@system.stacks[2]).to receive(:exist?).and_return(false)

      expect(@system).to receive(:sleep).once.ordered
      expect(@system.stacks[0]).to receive(:destroy).ordered
      expect(@system.stacks[2]).to receive(:destroy).ordered
      expect(@system).to receive(:sleep).once.ordered
      expect(@system.stacks[1]).to receive(:destroy).ordered

      @system.destroy_stacks
    end

    it 'ensure destroy platform when some error occurred while destroying optional' do
      allow(@system.stacks[0]).to receive(:destroy).and_raise
      expect(@system.stacks[1]).to receive(:destroy)

      expect { @system.destroy_stacks }.to raise_error RuntimeError
    end
  end
end
