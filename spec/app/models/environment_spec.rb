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

    @environment = Environment.new
    @environment.name = 'test'
    @environment.candidates << FactoryGirl.build(:candidate, environment: @environment, cloud: @cloud_aws, priority: 1)
    @environment.candidates << FactoryGirl.build(:candidate, environment: @environment, cloud: @cloud_openstack, priority: 2)
    @environment.system = FactoryGirl.create(:system)
    @environment.blueprint = FactoryGirl.create(:blueprint)

    @environment.stacks << FactoryGirl.build(:stack, environment: @environment)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @environment.save! }.to change { Environment.count }.by(1)
    end
  end

  describe '#initialize' do
    it 'set empty JSON to template_parameters' do
      expect(@environment.template_parameters).to eq('{}')
    end

    it 'set PENDING status' do
      expect(@environment.status).to eq(:PENDING)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@environment.valid?).to be_truthy
    end

    it 'returns false when name is unset' do
      @environment.name = nil
      expect(@environment.valid?).to be_falsey

      @environment.name = ''
      expect(@environment.valid?).to be_falsey
    end

    it 'returns false when system is unset' do
      @environment.system = nil
      expect(@environment.valid?).to be_falsey
    end

    it 'returns false when blueprint is unset' do
      @environment.blueprint = nil
      expect(@environment.valid?).to be_falsey
    end

    it 'returns false when candidates is empty' do
      @environment.candidates.delete_all
      expect(@environment.valid?).to be_falsey
    end

    xit 'returns false when stacks is empty' do
      @environment.stacks.delete_all
      expect(@environment.valid?).to be_falsey
    end

    it 'returns false when clouds collection has duplicate cloud' do
      @environment.candidates.delete_all
      @environment.candidates << FactoryGirl.build(:candidate, environment: @environment, cloud: @cloud_aws)
      @environment.candidates << FactoryGirl.build(:candidate, environment: @environment, cloud: @cloud_aws)
      expect(@environment.valid?).to be_falsey
    end
  end

  describe '#destroy' do
    before do
      allow(@environment).to receive(:destroy_stacks)
    end

    it 'delete environment record' do
      @environment.save!
      expect { @environment.destroy }.to change { Environment.count }.by(-1)
    end

    it 'delete all candidate records' do
      @environment.save!
      expect(@environment.clouds.size).to eq(2)
      expect(@environment.candidates.size).to eq(2)

      expect { @environment.destroy }.to change { Candidate.count }.by(-2)
    end

    it 'delete all relatioship between environment and cloud' do
      @environment.save!

      expect(@environment.clouds.size).to eq(2)
      expect(@environment.candidates.size).to eq(2)

      @environment.clouds.delete_all

      expect(@environment.clouds.size).to eq(0)
      expect(@environment.candidates.size).to eq(0)
    end

    it 'call #destroy_stacks callback' do
      expect(@environment).to receive(:destroy_stacks)
      @environment.destroy
    end

    it 'doesn\'t call #destroy_stacks callback when empty stacks' do
      @environment.stacks.delete_all
      expect(@environment).not_to receive(:destroy_stacks)
      @environment.destroy
    end

    it 'delete environment that has multiple stacks' do
      threads = Thread.list

      @environment.save!
      @environment.stacks.delete_all
      platform_pattern = FactoryGirl.create(:pattern, :platform)
      optional_pattern = FactoryGirl.create(:pattern, :optional)
      FactoryGirl.create(:stack, environment: @environment, status: :CREATE_COMPLETE, pattern: platform_pattern)
      FactoryGirl.create(:stack, environment: @environment, status: :CREATE_COMPLETE, pattern: optional_pattern)

      @environment.destroy

      (Thread.list - threads).each(&:join)
    end
  end

  describe '#enable_monitoring' do
    it 'is called from save callback' do
      expect(@environment).to receive(:enable_monitoring)
      @environment.monitoring_host = 'example.com'
      @environment.save!
    end

    it 'isn\'t called from save callback when monitoring_host isn\'t changed' do
      allow(@environment).to receive(:enable_monitoring)
      @environment.monitoring_host = 'example.com'
      @environment.save!

      expect(@environment).not_to receive(:enable_monitoring)
      @environment.monitoring_host = 'example.com'
      @environment.save!
    end

    it 'isn\'t called from save callback when monitoring_host is nil' do
      allow(@environment).to receive(:enable_monitoring)
      @environment.monitoring_host = 'example.com'
      @environment.save!

      expect(@environment).not_to receive(:enable_monitoring)
      @environment.monitoring_host = nil
      @environment.save!
    end

    it 'call ZabbixClient#register' do
      expect(CloudConductor::ZabbixClient).to receive_message_chain(:new, :register)
      @environment.monitoring_host = 'example.com'
      @environment.send(:enable_monitoring)
    end
  end

  describe '#update_dns' do
    it 'is called from save callback' do
      expect(@environment).to receive(:update_dns)
      @environment.ip_address = '127.0.0.1'
      @environment.save!
    end

    it 'isn\'t called from save callback when ip_address is nil' do
      expect(@environment).not_to receive(:update_dns)
      @environment.ip_address = nil
      @environment.save!
    end

    it 'call DNSClient#update when ip_address isn\'t nil' do
      @environment.ip_address = '127.0.0.1'
      expect(CloudConductor::DNSClient).to receive_message_chain(:new, :update).with(@environment.domain, @environment.ip_address)
      @environment.send(:update_dns)
    end
  end

  describe '#dup' do
    it 'duplicate all attributes in environment without name, ip_address and monitoring_host' do
      duplicated_environment = @environment.dup
      expect(duplicated_environment.domain).to eq(@environment.domain)
    end

    it 'duplicate name with uuid to avoid unique constraint' do
      duplicated_environment = @environment.dup
      expect(duplicated_environment.name).not_to eq(@environment.name)
      expect(duplicated_environment.name).to match(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end

    it 'clear ip_address' do
      @environment.ip_address = '192.168.0.1'
      expect(@environment.dup.ip_address).to be_nil
    end

    it 'clear monitoring_host' do
      @environment.monitoring_host = 'example.com'
      expect(@environment.dup.monitoring_host).to be_nil
    end

    it 'clear template_parameters' do
      @environment.template_parameters = '{"SubnetId": "123456"}'
      expect(@environment.dup.template_parameters).to eq('{}')
    end

    it 'duplicated associated clouds' do
      expect(@environment.dup.clouds).to eq(@environment.clouds)
    end

    it 'duplicated candidates' do
      candidates = @environment.dup.candidates
      expect(candidates).not_to match_array(@environment.candidates)
      expect(candidates.map(&:cloud)).to match_array(@environment.candidates.map(&:cloud))
      expect(candidates.map(&:priority)).to match_array(@environment.candidates.map(&:priority))
      expect(candidates).to be_all(&:new_record?)
    end

    it 'duplicate stacks without save' do
      stacks = @environment.dup.stacks
      expect(stacks.size).to eq(@environment.stacks.size)
      expect(stacks).to be_all(&:new_record?)
    end
  end

  describe '#consul' do
    it 'will fail when ip_address does not specified' do
      @environment.ip_address = nil
      expect { @environment.consul }.to raise_error('ip_address does not specified')
    end

    it 'return consul client when ip_address already specified' do
      @environment.ip_address = '127.0.0.1'
      expect(@environment.consul).to be_a Consul::Client
    end
  end

  describe '#event' do
    it 'will fail when ip_address does not specified' do
      @environment.ip_address = nil
      expect { @environment.event }.to raise_error('ip_address does not specified')
    end

    it 'return event client when ip_address already specified' do
      @environment.ip_address = '127.0.0.1'
      expect(@environment.event).to be_is_a CloudConductor::Event
    end
  end

  describe '#as_json' do
    before do
      @environment.id = 1
      @environment.monitoring_host = 'example.com'
      @environment.ip_address = '127.0.0.1'
      allow(@environment).to receive(:status).and_return(:PROGRESS)
    end

    it 'return attributes as json format' do
      json = @environment.as_json
      expect(json['id']).to eq(@environment.id)
      expect(json['name']).to eq(@environment.name)
      expect(json['monitoring_host']).to eq(@environment.monitoring_host)
      expect(json['ip_address']).to eq(@environment.ip_address)
      expect(json['domain']).to eq(@environment.domain)
      expect(json['template_parameters']).to eq(@environment.template_parameters)
      expect(json['status']).to eq(@environment.status)
    end
  end

  describe '#destroy_stacks' do
    before do
      pattern1 = FactoryGirl.create(:pattern, :optional)
      pattern2 = FactoryGirl.create(:pattern, :platform)
      pattern3 = FactoryGirl.create(:pattern, :optional)

      @environment.stacks.delete_all
      @environment.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, environment: @environment, pattern: pattern1, cloud: @cloud_aws)
      @environment.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, environment: @environment, pattern: pattern2, cloud: @cloud_aws)
      @environment.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, environment: @environment, pattern: pattern3, cloud: @cloud_aws)

      @environment.save!

      allow(Thread).to receive(:new).and_yield
      allow(@environment).to receive(:sleep)
      allow_any_instance_of(Stack).to receive(:destroy)

      original_timeout = Timeout.method(:timeout)
      allow(Timeout).to receive(:timeout) do |_, &block|
        original_timeout.call(0.1, &block)
      end
    end

    it 'destroy all stacks of environment' do
      expect(@environment.stacks).not_to be_empty
      @environment.destroy_stacks
      expect(@environment.stacks).to be_empty
    end

    it 'create other thread to destroy stacks use their dependencies' do
      expect(Thread).to receive(:new).and_yield
      @environment.destroy_stacks
    end

    it 'destroy optional patterns before platform' do
      expect(@environment.stacks[0]).to receive(:destroy).ordered
      expect(@environment.stacks[2]).to receive(:destroy).ordered
      expect(@environment.stacks[1]).to receive(:destroy).ordered

      @environment.destroy_stacks
    end

    it 'doesn\'t destroy platform pattern until timeout if optional pattern can\'t destroy' do
      allow(@environment).to receive(:stack_destroyed?).and_return(-> (_) { false })

      expect(@environment).to receive(:sleep).once.ordered
      expect(@environment.stacks[0]).to receive(:destroy).ordered
      expect(@environment.stacks[2]).to receive(:destroy).ordered
      expect(@environment).to receive(:sleep).at_least(:once).ordered
      expect(@environment.stacks[1]).to receive(:destroy).ordered

      @environment.destroy_stacks
    end

    it 'wait and destroy platform pattern when destroyed all optional patterns' do
      allow(@environment).to receive(:stack_destroyed?).and_return(-> (_) { false }, -> (_) { true })

      expect(@environment).to receive(:sleep).once.ordered
      expect(@environment.stacks[0]).to receive(:destroy).ordered
      expect(@environment.stacks[2]).to receive(:destroy).ordered
      expect(@environment).to receive(:sleep).once.ordered
      expect(@environment.stacks[1]).to receive(:destroy).ordered

      @environment.destroy_stacks
    end

    it 'ensure destroy platform when some error occurred while destroying optional' do
      allow(@environment.stacks[0]).to receive(:destroy).and_raise
      expect(@environment.stacks[1]).to receive(:destroy)

      expect { @environment.destroy_stacks }.to raise_error RuntimeError
    end
  end

  describe '#stack_destroyed?' do
  end
end
