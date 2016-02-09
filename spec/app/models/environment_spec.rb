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
  include_context 'default_resources'

  before do
    allow_any_instance_of(Project).to receive(:create_preset_roles)

    @cloud_aws = FactoryGirl.create(:cloud, :aws, project: project)
    @cloud_openstack = FactoryGirl.create(:cloud, :openstack, project: project)

    @system = System.eager_load(:project).find(system)
    @blueprint_history = FactoryGirl.build(:blueprint_history, blueprint: blueprint)
    @environment = FactoryGirl.build(:environment, system: @system, blueprint_history: @blueprint_history,
                                                   candidates_attributes: [{ cloud_id: @cloud_aws.id, priority: 1 },
                                                                           { cloud_id: @cloud_openstack.id, priority: 2 }])
    allow(CloudConductor::Config).to receive_message_chain(:system_build, :timeout).and_return(1800)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @environment.save! }.to change { Environment.count }.by(1)
    end

    it 'call #create_stacks' do
      expect(@environment).to receive(:create_or_update_stacks)
      @environment.save!
    end

    it 'create with long text' do
      @environment.description = '*' * 256
      @environment.save!
    end
  end

  describe '#initialize' do
    it 'set empty JSON to platform_outputs' do
      expect(@environment.platform_outputs).to eq('{}')
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

    it 'returns false when clouds collection has duplicate cloud' do
      @environment.candidates.delete_all
      @environment.candidates << FactoryGirl.build(:candidate, environment: @environment, cloud: @cloud_aws)
      @environment.candidates << FactoryGirl.build(:candidate, environment: @environment, cloud: @cloud_aws)
      expect(@environment.valid?).to be_falsey
    end
  end

  describe '#destroy' do
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

    it 'call #destroy_stacks_in_background callback' do
      expect(@environment).to receive(:destroy_stacks_in_background)
      @environment.destroy
    end
  end

  describe '#destroy_stacks_in_background' do
    it 'call #destroy_stacks in background thread' do
      allow(@environment).to receive(:destroy_stacks_in_background).and_call_original
      allow(Thread).to receive(:new).and_yield
      expect(@environment).to receive(:destroy_stacks)
      @environment.destroy_stacks_in_background
    end
  end

  describe '#create_stacks' do
  end

  describe '#update_stacks' do
  end

  describe '#build' do
    before do
      @environment.candidates << FactoryGirl.build(:candidate, environment: @environment, cloud: cloud)
      @environment.save!

      @builder = double(:builder, build: true)
      allow(CloudConductor::Builders).to receive(:builder).and_return(@builder)
    end

    it 'call Builder#build just once when successfully created' do
      expect(@builder).to receive(:build).once.and_return(true)
      @environment.build
    end

    it 'call Builder#build twice when failed to create first cloud' do
      expect(@builder).to receive(:build).twice.and_return(false, true)
      @environment.build
    end

    it 'call Builder#build twice when raise exception while creating on first cloud' do
      count = 0
      expect(@builder).to receive(:build).twice do
        count += 1
        count <= 1 ? fail : true
      end
      @environment.build
    end
  end

  describe '#dup' do
    it 'duplicate all attributes in environment without some attributes which dependent previous environment' do
      @environment.save!
      duplicated_environment = @environment.dup
      expect(duplicated_environment.system).to eq(@environment.system)
      expect(duplicated_environment.blueprint_history).to eq(@environment.blueprint_history)
      expect(duplicated_environment.description).to eq(@environment.description)
    end

    it 'duplicate name with uuid to avoid unique constraint' do
      duplicated_environment = @environment.dup
      expect(duplicated_environment.name).not_to eq(@environment.name)
      expect(duplicated_environment.name).to match(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end

    it 'clear frontend_address' do
      @environment.frontend_address = '192.168.0.1'
      expect(@environment.dup.frontend_address).to be_nil
    end

    it 'clear consul_addresses' do
      @environment.consul_addresses = '192.168.0.1, 192.168.0.2'
      expect(@environment.dup.consul_addresses).to be_nil
    end

    it 'clear platform_outputs' do
      @environment.platform_outputs = '{"SubnetId": "123456"}'
      expect(@environment.dup.platform_outputs).to eq('{}')
    end

    it 'clear status to :PENDING' do
      @environment.status = :CREATE_COMPLETE
      expect(@environment.dup.status).to eq(:PENDING)
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

    it 'duplicate deployments without save' do
      @environment.deployments << FactoryGirl.build(:deployment, environment: @environment, application_history: application_history, status: :DEPLOY_COMPLETE)

      deployments = @environment.dup.deployments
      expect(deployments.size).to eq(@environment.deployments.size)
      expect(deployments).to be_all(&:new_record?)
    end
  end

  describe '#consul' do
    it 'will fail when consul_addresses does not specified' do
      @environment.consul_addresses = nil
      expect { @environment.consul }.to raise_error('consul_addresses does not specified')
    end

    it 'return consul client when consul_addresses already specified' do
      @environment.consul_addresses = '127.0.0.1'
      expect(@environment.consul).to be_a Consul::Client
    end
  end

  describe '#event' do
    it 'will fail when consul_addresses does not specified' do
      @environment.consul_addresses = nil
      expect { @environment.event }.to raise_error('consul_addresses does not specified')
    end

    it 'return event client when consul_addresses already specified' do
      @environment.consul_addresses = '127.0.0.1'
      expect(@environment.event).to be_is_a CloudConductor::Event
    end
  end

  describe '#basename' do
    it 'return name without UUID' do
      @environment.name = "dummy-#{SecureRandom.uuid}"
      expect(@environment.basename).to eq('dummy')
    end

    it 'return original name when name hasn\'t UUID' do
      @environment.name = 'dummy'
      expect(@environment.basename).to eq('dummy')
    end
  end

  describe '#as_json' do
    before do
      @environment.id = 1
      @environment.frontend_address = '127.0.0.1'
      @environment.consul_addresses = '192.168.0.1, 192.168.0.2'
      allow(@environment).to receive(:status).and_return(:PROGRESS)
      allow(@environment).to receive(:application_status).and_return(:DEPLOY_COMPLETE)
    end

    it 'return attributes as hash' do
      hash = @environment.as_json
      expect(hash['id']).to eq(@environment.id)
      expect(hash['name']).to eq(@environment.name)
      expect(hash['frontend_address']).to eq(@environment.frontend_address)
      expect(hash['consul_addresses']).to eq(@environment.consul_addresses)
      expect(hash['status']).to eq(@environment.status)
      expect(hash['application_status']).to eq(@environment.application_status)
    end
  end

  describe '#destroy_stacks' do
    before do
      @builder = double(:builder, build: true)
      allow(CloudConductor::Builders).to receive(:builder).and_return(@builder)
    end

    it 'does not call Builder#destroy when stacks are empty' do
      expect(@builder).not_to receive(:destroy)
      @environment.destroy_stacks
    end

    it 'call Builder#destroy' do
      pattern_snapshot = FactoryGirl.build(:pattern_snapshot, type: 'optional', blueprint_history: @blueprint_history)
      @environment.stacks << FactoryGirl.build(:stack, status: :CREATE_COMPLETE, environment: @environment, pattern_snapshot: pattern_snapshot, cloud: @cloud_aws)

      expect(@builder).to receive(:destroy)
      @environment.destroy_stacks
    end
  end

  describe '#application_status' do
    before do
      @environment.status = :CREATE_COMPLETE
    end

    it 'return :NOT_DEPLOYED if application haven\'t deployed' do
      expect(@environment.application_status).to eq(:NOT_DEPLOYED)
    end

    it 'return :ERROR if deployments have least one :ERROR status' do
      FactoryGirl.create(:deployment, environment: @environment, status: :PROGRESS)
      FactoryGirl.create(:deployment, environment: @environment, status: :ERROR)
      FactoryGirl.create(:deployment, environment: @environment, status: :DEPLOY_COMPLETE)
      expect(@environment.application_status).to eq(:ERROR)
    end

    it 'return :PROGRESS if deployments have least one :PROGRESS status' do
      FactoryGirl.create(:deployment, environment: @environment, status: :DEPLOY_COMPLETE)
      FactoryGirl.create(:deployment, environment: @environment, status: :PROGRESS)
      FactoryGirl.create(:deployment, environment: @environment, status: :DEPLOY_COMPLETE)
      expect(@environment.application_status).to eq(:PROGRESS)
    end

    it 'return :DEPLOY_COMPLETE if all deployments have completed' do
      FactoryGirl.create(:deployment, environment: @environment, status: :DEPLOY_COMPLETE)
      FactoryGirl.create(:deployment, environment: @environment, status: :DEPLOY_COMPLETE)
      expect(@environment.application_status).to eq(:DEPLOY_COMPLETE)
    end

    it 'return :ERROR if deployments have invalid status' do
      FactoryGirl.create(:deployment, environment: @environment, status: :INVALID)
      FactoryGirl.create(:deployment, environment: @environment, status: :INVALID)
      FactoryGirl.create(:deployment, environment: @environment, status: :DEPLOY_COMPLETE)
      expect(@environment.application_status).to eq(:ERROR)
    end

    it 'return :DEPLOY_COMPLETE if latest deployment has succeeded each application' do
      application1 = FactoryGirl.build(:application, system: @system)
      application2 = FactoryGirl.build(:application, system: @system)

      history1 = FactoryGirl.build(:application_history, application: application1)
      history2 = FactoryGirl.build(:application_history, application: application2)
      history3 = FactoryGirl.build(:application_history, application: application1)

      FactoryGirl.create(:deployment, environment: @environment, application_history: history1, status: :ERROR)
      FactoryGirl.create(:deployment, environment: @environment, application_history: history2, status: :DEPLOY_COMPLETE)
      FactoryGirl.create(:deployment, environment: @environment, application_history: history3, status: :DEPLOY_COMPLETE)

      expect(@environment.application_status).to eq(:DEPLOY_COMPLETE)
    end
  end

  describe '#latest_deployments' do
    before do
      @environment.status = :CREATE_COMPLETE
    end

    it 'return latest deployments each application' do
      application1 = FactoryGirl.build(:application, system: @system)
      application2 = FactoryGirl.build(:application, system: @system)

      history1 = FactoryGirl.build(:application_history, application: application1)
      history2 = FactoryGirl.build(:application_history, application: application2)
      history3 = FactoryGirl.build(:application_history, application: application1)

      _deployment1 = FactoryGirl.create(:deployment, environment: @environment, application_history: history1)
      deployment2 = FactoryGirl.create(:deployment, environment: @environment, application_history: history2)
      deployment3 = FactoryGirl.create(:deployment, environment: @environment, application_history: history3)

      expect(@environment.latest_deployments).to match_array([deployment2, deployment3])
    end
  end

  describe '#cfn_parameters' do
    it 'returns extract part of JSON for CloudFormation/Heat from template_parameters' do
      @environment.template_parameters = <<-EOS
      {
        "dummy_pattern": {
          "cloud_formation": {
            "WebInstanceType": {
              "type": "static",
              "value": "t2.micro"
            },
            "WebInstanceSize": {
              "type": "static",
              "value": "2"
            }
          },
          "terraform": {
            "aws": {
              "web_instance_type": {
                "type": "static",
                "value": "t2.small"
              }
            }
          }
        }
      }
      EOS
      result = @environment.send(:cfn_parameters, 'dummy_pattern')
      expect(result).to eq(
        'WebInstanceType' => 't2.micro',
        'WebInstanceSize' => '2'
      )
    end
  end
end
