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
  include_context 'default_resources'

  before do
    allow_any_instance_of(Project).to receive(:create_preset_roles)

    @system = FactoryGirl.build(:system, project: project)

    allow(CloudConductor::Config).to receive_message_chain(:zabbix, :enabled).and_return(true)
  end

  describe '#save' do
    let(:blueprint_history) { FactoryGirl.build(:blueprint_history, blueprint: blueprint) }
    let(:environment) { FactoryGirl.build(:environment, system: @system, blueprint_history: blueprint_history, candidates_attributes: [FactoryGirl.attributes_for(:candidate, cloud: cloud)]) }
    it 'create with valid parameters' do
      expect { @system.save! }.to change { System.count }.by(1)
    end

    it 'create with long text' do
      @system.description = '*' * 256
      @system.save!
    end

    it 'call #update_dns callback if system has primary environment' do
      @system.environments << environment
      @system.primary_environment = @system.environments.first

      expect(@system).to receive(:update_dns)
      @system.save!
    end

    it 'doesn\'t call #update_dns and #enable_monitoring callback if system hasn\'t primary environment' do
      @system.environments << environment

      expect(@system).not_to receive(:update_dns)
      expect(@system).not_to receive(:enable_monitoring)
      @system.save!
    end

    it 'doesn\'t call #update_dns and #enable_monitoring callback if system hasn\'t domain' do
      @system.domain = nil

      expect(@system).not_to receive(:update_dns)
      expect(@system).not_to receive(:enable_monitoring)
      @system.save!
    end

    it 'update status of primary environment when some error occurred while request to DNS' do
      environment.status = :CREATE_COMPLETE
      environment.save!
      @system.environments << environment
      @system.primary_environment = @system.environments.first

      allow(@system).to receive(:update_dns).and_raise
      expect { @system.save! }.to raise_error(RuntimeError)

      expect(Environment.find(environment).status).to eq(:ERROR)
    end
  end

  describe '#destroy' do
    it 'delete system record' do
      @system.save!
      expect { @system.destroy }.to change { System.count }.by(-1)
    end

    it 'delete all application records' do
      @system.applications << FactoryGirl.build(:application, system: @system)
      @system.applications << FactoryGirl.build(:application, system: @system)

      @system.save!

      system = System.eager_load(:applications).find(@system)

      expect(system.applications.size).to eq(2)
      expect { system.destroy }.to change { Application.count }.by(-2)
    end

    it 'delete all environment records' do
      @system.environments << environment

      expect(@system.environments.size).to eq(1)
      expect { @system.destroy }.to change { Environment.count }.by(-1)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@system.valid?).to be_truthy
    end

    it 'returns false when project is unset' do
      @system.project = nil
      expect(@system.valid?).to be_falsey
    end

    it 'returns false when name is unset' do
      @system.name = nil
      expect(@system.valid?).to be_falsey

      @system.name = ''
      expect(@system.valid?).to be_falsey
    end
  end

  describe '#update_dns' do
    it 'call DNSClient#update when frontend_address isn\'t nil' do
      allow(@system).to receive(:update_dns).and_call_original

      @system.environments << environment
      @system.primary_environment = @system.environments.first
      environment.frontend_address = '127.0.0.1'

      expect(CloudConductor::DNSClient).to receive_message_chain(:new, :update).with(@system.domain, '127.0.0.1')
      @system.send(:update_dns)
    end
  end
end
