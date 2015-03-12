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
    @deployment = Deployment.new
    @deployment.environment = environment
    @deployment.environment.status = :CREATE_COMPLETE
    @deployment.application_history = application_history

    @event = double(:event, fire: 1)
    allow(@event).to receive_message_chain(:find, :finished?).and_return(true)
    allow(@event).to receive_message_chain(:find, :success?).and_return(true)
    allow(environment).to receive(:event).and_return(@event)
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
      expect { @deployment.save! }.to change { Deployment.count }.by(1)
    end

    it 'call #consul_request callback' do
      environment.ip_address = '127.0.0.1'

      expect(@deployment).to receive(:consul_request)
      @deployment.save!
    end
  end

  describe '#consul_request' do
    it 'trigger deploy event' do
      expect(@event).to receive(:fire).with(:deploy, be_a(Hash))
      @deployment.send(:consul_request)
    end

    it 'change status and event when call consul_request' do
      expect(@deployment.status).to eq(:NOT_DEPLOYED)
      expect(@deployment.event).to be_nil

      @deployment.send(:consul_request)

      expect(@deployment.status).to eq(:PROGRESS)
      expect(@deployment.event).not_to be_nil
    end
  end

  describe '#update_status' do
    it 'update status' do
      allow_any_instance_of(CloudConductor::Event).to receive(:find)
        .and_return(double(success?: true, finished?: true))
      deployment = FactoryGirl.create(:deployment, environment: environment, application_history: application_history, status: :PROGRESS)
      deployment.send(:update_status)
      expect(deployment.reload.status).to eq('DEPLOY_COMPLETE')
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
end
