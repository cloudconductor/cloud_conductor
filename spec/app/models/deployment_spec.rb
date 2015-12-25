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
describe Deployment do
  include_context 'default_resources'

  before do
    allow_any_instance_of(Project).to receive(:create_preset_roles)

    @environment = Environment.eager_load(:system).find(environment)
    @application_history = ApplicationHistory.eager_load(:application).find(application_history)
    @deployment = FactoryGirl.build(:deployment, environment: @environment, application_history: @application_history)

    @event = double(:event, fire: 1, sync_fire: 1)
    allow(@event).to receive_message_chain(:find, :finished?).and_return(true)
    allow(@event).to receive_message_chain(:find, :success?).and_return(true)
    allow(@environment).to receive(:event).and_return(@event)
  end

  describe '#initialize' do
    it 'set status to :NOT_DEPLOYED' do
      expect(@deployment.status).to eq(:NOT_DEPLOYED)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@deployment.valid?).to be_truthy
    end

    it 'returns false when environment is unset' do
      @deployment.environment = nil
      expect(@deployment.valid?).to be_falsey
    end

    it 'returns false when application_history is unset' do
      @deployment.application_history = nil
      expect(@deployment.valid?).to be_falsey
    end
  end

  describe '#save' do
    it 'create with valid parameters' do
      allow(@deployment).to receive(:consul_request)
      expect { @deployment.save! }.to change { Deployment.count }.by(1)
    end

    it 'call #consul_request callback' do
      environment.ip_address = '127.0.0.1'

      expect(@deployment).to receive(:consul_request)
      @deployment.save!
    end
  end

  describe '#consul_request' do
    before do
      allow(@deployment).to receive(:consul_request).and_call_original
    end

    it 'call #deploy_application to deploy application in background' do
      expect(@deployment).to receive(:deploy_application)
      @deployment.send(:consul_request)
    end

    it 'change status and event when call consul_request' do
      allow(@deployment).to receive(:deploy_application)
      expect(@deployment.status).to eq(:NOT_DEPLOYED)

      @deployment.send(:consul_request)

      expect(@deployment.status).to eq(:PROGRESS)
    end
  end

  describe '#deploy_application' do
    before do
      allow(Thread).to receive(:new).and_yield
      allow(@deployment).to receive(:consul_request)
      allow(@deployment).to receive(:update_dns_record)
      @deployment.save!
    end

    it 'deploy application and serverspec in background' do
      expect(Thread).to receive(:new).and_yield
      expect(@event).to receive(:sync_fire).with(:deploy, be_a(Hash))
      expect(@event).to receive(:sync_fire).with(:spec)
      @deployment.deploy_application
    end

    it 'update deployment status to DEPLOY_COMPLETE when event has deployed without error' do
      allow(@event).to receive(:sync_fire).with(:deploy, be_a(Hash))
      allow(@event).to receive(:sync_fire).with(:spec)
      @deployment.deploy_application
      expect(@deployment.status).to eq(:DEPLOY_COMPLETE)
    end

    it 'update deployment status to ERROR when some error occurred while deploy event' do
      allow(@event).to receive(:sync_fire).with(:deploy, be_a(Hash)).and_raise
      @deployment.deploy_application
      expect(@deployment.status).to eq(:ERROR)
    end

    it 'update deployment status to ERROR when some error occurred while serverspec' do
      allow(@event).to receive(:sync_fire).with(:deploy, be_a(Hash))
      allow(@event).to receive(:sync_fire).with(:spec).and_raise
      @deployment.deploy_application
      expect(@deployment.status).to eq(:ERROR)
    end
  end

  describe '#dup' do
    it 'clear environment' do
      expect(@deployment.dup.environment).to be_nil
    end

    it 'clear status to :NOT_DEPLOYED' do
      @deployment.status = :DEPLOY_COMPLETE
      expect(@deployment.dup.status).to eq(:NOT_DEPLOYED)
    end
  end

  describe '#update_dns_record' do
    before do
      @client = double(:dns_client, update: true)
      allow(CloudConductor::DNSClient).to receive(:new).and_return(@client)
    end

    it 'register CNAME record to DNS server' do
      expect(@client).to receive(:update).with('app.example.com', 'example.com', 'CNAME')
      @deployment.send(:update_dns_record)
    end

    it 'does not register CNAME record to DNS server when system domain is null' do
      @environment.system.domain = nil
      expect(@client).not_to receive(:update)
      @deployment.send(:update_dns_record)
    end

    it 'does not register CNAME record to DNS server when application domain is null' do
      @application_history.application.domain = nil
      expect(@client).not_to receive(:update)
      @deployment.send(:update_dns_record)
    end
  end
end
