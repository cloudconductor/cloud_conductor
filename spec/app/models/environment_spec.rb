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
    @cloud_aws = FactoryGirl.create(:cloud, :aws)
    @cloud_openstack = FactoryGirl.create(:cloud, :openstack)

    @environment = FactoryGirl.build(:environment, system: system, blueprint: blueprint,
                                                   candidates_attributes: [{ cloud_id: @cloud_aws.id, priority: 1 },
                                                                           { cloud_id: @cloud_openstack.id, priority: 2 }])
    allow(@environment).to receive(:create_or_update_stacks)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @environment.save! }.to change { Environment.count }.by(1)
    end

    it 'call #create_stacks' do
      expect(@environment).to receive(:create_or_update_stacks)
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
    before do
      allow(Thread).to receive(:new).and_yield
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
      @environment.stacks << FactoryGirl.build(:stack, environment: @environment)
      expect(@environment).to receive(:destroy_stacks)
      @environment.destroy
    end

    it 'delete environment that has multiple stacks' do
      threads = Thread.list

      @environment.save!
      @environment.stacks.delete_all
      platform_pattern = FactoryGirl.create(:pattern, :platform, images: [FactoryGirl.build(:image, base_image: base_image, cloud: cloud)])
      optional_pattern = FactoryGirl.create(:pattern, :optional, images: [FactoryGirl.build(:image, base_image: base_image, cloud: cloud)])
      FactoryGirl.create(:stack, environment: @environment, status: :CREATE_COMPLETE, pattern: platform_pattern)
      FactoryGirl.create(:stack, environment: @environment, status: :CREATE_COMPLETE, pattern: optional_pattern)

      @environment.destroy

      (Thread.list - threads).each(&:join)
    end
  end

  describe '#create_stacks' do
  end

  describe '#update_stacks' do
  end

  describe '#dup' do
    it 'duplicate all attributes in environment without name and ip_address' do
      duplicated_environment = @environment.dup
      expect(duplicated_environment.system).to eq(@environment.system)
      expect(duplicated_environment.blueprint).to eq(@environment.blueprint)
      expect(duplicated_environment.description).to eq(@environment.description)
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
      @environment.ip_address = '127.0.0.1'
      allow(@environment).to receive(:status).and_return(:PROGRESS)
      allow(@environment).to receive(:application_status).and_return(:DEPLOY_COMPLETE)
    end

    it 'return attributes as hash' do
      hash = @environment.as_json
      expect(hash['id']).to eq(@environment.id)
      expect(hash['name']).to eq(@environment.name)
      expect(hash['ip_address']).to eq(@environment.ip_address)
      expect(hash['platform_outputs']).to eq(@environment.platform_outputs)
      expect(hash['status']).to eq(@environment.status)
      expect(hash['application_status']).to eq(@environment.application_status)
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

      allow(@environment).to receive(:sleep)
      allow_any_instance_of(Stack).to receive(:destroy)

      original_timeout = Timeout.method(:timeout)
      allow(Timeout).to receive(:timeout) do |_, &block|
        original_timeout.call(0.1, &block)
      end

      allow(@environment).to receive(:stack_destroyed?).and_return(-> (_) { true })
    end

    it 'destroy all stacks of environment' do
      expect(@environment.stacks).not_to be_empty
      @environment.destroy_stacks
      expect(@environment.stacks).to be_empty
    end

    it 'destroy optional patterns before platform' do
      expect(@environment.stacks[0]).to receive(:destroy).ordered
      expect(@environment.stacks[2]).to receive(:destroy).ordered
      expect(@environment.stacks[1]).to receive(:destroy).ordered

      @environment.destroy_stacks
    end

    it 'doesn\'t destroy platform pattern until timeout if optional pattern can\'t destroy' do
      allow(@environment).to receive(:stack_destroyed?).and_return(-> (_) { false })

      expect(@environment.stacks[0]).to receive(:destroy).ordered
      expect(@environment.stacks[2]).to receive(:destroy).ordered
      expect(@environment).to receive(:sleep).at_least(:once).ordered
      expect(@environment.stacks[1]).to receive(:destroy).ordered

      @environment.destroy_stacks
    end

    it 'wait and destroy platform pattern when destroyed all optional patterns' do
      allow(@environment).to receive(:stack_destroyed?).and_return(-> (_) { false }, -> (_) { true })

      expect(@environment.stacks[0]).to receive(:destroy).ordered
      expect(@environment.stacks[2]).to receive(:destroy).ordered
      expect(@environment).to receive(:sleep).once.ordered
      expect(@environment.stacks[1]).to receive(:destroy).ordered

      @environment.destroy_stacks
    end

    it 'ensure destroy platform when some error occurred while destroying optional' do
      allow(@environment.stacks[0]).to receive(:destroy).and_raise(RuntimeError)
      expect(@environment.stacks[1]).to receive(:destroy)
      expect { @environment.destroy_stacks }.to raise_error(RuntimeError)
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
      application1 = FactoryGirl.create(:application)
      application2 = FactoryGirl.create(:application)

      history1 = FactoryGirl.create(:application_history, application: application1)
      history2 = FactoryGirl.create(:application_history, application: application2)
      history3 = FactoryGirl.create(:application_history, application: application1)

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
      application1 = FactoryGirl.create(:application)
      application2 = FactoryGirl.create(:application)

      history1 = FactoryGirl.create(:application_history, application: application1)
      history2 = FactoryGirl.create(:application_history, application: application2)
      history3 = FactoryGirl.create(:application_history, application: application1)

      _deployment1 = FactoryGirl.create(:deployment, environment: @environment, application_history: history1)
      deployment2 = FactoryGirl.create(:deployment, environment: @environment, application_history: history2)
      deployment3 = FactoryGirl.create(:deployment, environment: @environment, application_history: history3)

      expect(@environment.latest_deployments).to match_array([deployment2, deployment3])
    end
  end
end
