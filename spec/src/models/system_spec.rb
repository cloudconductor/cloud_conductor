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
    @system.monitoring_host = nil
    @system.domain = 'example.com'

    @system.add_cloud(@cloud_aws, 1)
    @system.add_cloud(@cloud_openstack, 2)

    CloudConductor::DNSClient.stub_chain(:new, :update)
    CloudConductor::ZabbixClient.stub_chain(:new, :register)

    @system.applications << FactoryGirl.create(:application)
    @system.applications << FactoryGirl.create(:application)
    @system.applications.first.histories << FactoryGirl.build(:application_history)
    @system.applications.first.histories << FactoryGirl.build(:application_history)

    @system.stacks << FactoryGirl.create(:stack)
    @system.stacks << FactoryGirl.create(:stack)
    Stack.skip_callback :destroy, :before, :destroy_stack
  end

  after do
    Stack.set_callback :destroy, :before, :destroy_stack
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
    it 'duplicate all attributes in system without name and ip_address' do
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

    it 'destroy all stacks in target system' do
      @system.save!

      stack_count = Stack.count

      @system.destroy

      expect(Stack.count).to eq(stack_count - 2)
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

  describe '#send_application_payload' do
    before do
      @system.applications.clear
      @time = Time.now.strftime('%Y%m%d')

      @consul_client = double(:consul_client)
      Consul::Client.stub_chain(:connect, :kv).and_return @consul_client
    end

    it 'will send payload to consul' do
      application = FactoryGirl.create(:application, name: 'dummy', system: @system)
      application.histories << FactoryGirl.create(:application_history, application: application)
      @system.applications << application

      expected_payload = {
        cloudconductor: {
          applications: {
            'dummy' => {
              domain: 'example.com',
              type: 'static',
              version: "#{@time}-001",
              protocol: 'http',
              url: 'http://example.com/',
              parameters: { dummy: 'value' }
            }
          }
        }
      }

      @consul_client.should_receive(:merge).with(anything, expected_payload)

      @system.send_application_payload
    end

    it 'will send payload belongs to multiple applications to consul' do
      application1 = FactoryGirl.create(:application, name: 'dummy1', system: @system)
      application2 = FactoryGirl.create(:application, name: 'dummy2', system: @system)
      application1.histories << FactoryGirl.create(:application_history, application: application1)
      application2.histories << FactoryGirl.create(:application_history, application: application2)
      @system.applications << application1
      @system.applications << application2

      expected_payload = {
        cloudconductor: {
          applications: {
            'dummy1' => {
              domain: 'example.com',
              type: 'static',
              version: "#{@time}-001",
              protocol: 'http',
              url: 'http://example.com/',
              parameters: { dummy: 'value' }
            },
            'dummy2' => {
              domain: 'example.com',
              type: 'static',
              version: "#{@time}-001",
              protocol: 'http',
              url: 'http://example.com/',
              parameters: { dummy: 'value' }
            }
          }
        }
      }

      @consul_client.should_receive(:merge).with(anything, expected_payload)

      @system.send_application_payload
    end
  end

  describe '#deploy_applications' do
    before do
      @serf_client = double(:serf_client)
      @system.stub(:serf).and_return(@serf_client)
      @system.applications.clear
    end

    it 'will NOT request deploy event to serf when applications are empty' do
      @serf_client.should_not_receive(:call)
      @system.deploy_applications
    end

    it 'will request deploy event to serf' do
      application = FactoryGirl.create(:application, name: 'dummy', system: @system)
      application.histories << FactoryGirl.create(:application_history, application: application)
      @system.applications << application

      @serf_client.should_receive(:call).with('event', 'deploy')

      @system.deploy_applications
    end
  end
end
