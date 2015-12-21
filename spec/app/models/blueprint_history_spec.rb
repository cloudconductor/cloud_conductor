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
describe BlueprintHistory do
  include_context 'default_resources'

  before do
    @history = FactoryGirl.build(:blueprint_history, blueprint: blueprint)
    @history.version = 1

    allow(@history).to receive(:set_consul_secret_key)
    allow(@history).to receive(:set_version)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @history.save! }.to change { BlueprintHistory.count }.by(1)
    end

    it 'call #set_consul_secret_key callback' do
      expect(@history).to receive(:set_consul_secret_key)
      @history.save!
    end

    it 'call #set_version callback' do
      expect(@history).to receive(:set_version)
      @history.save!
    end

    it 'call #build_pattern_snapshots callback' do
      expect(@history).to receive(:build_pattern_snapshots)
      @history.save!
    end
  end

  describe '#destroy' do
    it 'delete blueprint history record' do
      @history.save!
      expect { @history.destroy }.to change { BlueprintHistory.count }.by(-1)
    end

    it 'delete all pattern history records' do
      @history.pattern_snapshots.delete_all
      @history.pattern_snapshots << FactoryGirl.create(:pattern_snapshot, blueprint_history: @history)
      @history.pattern_snapshots << FactoryGirl.create(:pattern_snapshot, blueprint_history: @history)

      expect(@history.pattern_snapshots.size).to eq(2)
      expect { @history.destroy }.to change { PatternSnapshot.count }.by(-2)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@history.valid?).to be_truthy
    end

    it 'returns false when blueprint is unset' do
      @history.blueprint = nil
      expect(@history.valid?).to be_falsey
    end
  end

  describe '#set_consul_secret_key' do
    before do
      allow(@history).to receive(:set_consul_secret_key).and_call_original
      allow(SecureRandom).to receive(:base64).with(16).and_return('PDtYpNJ1wLvkSJw94SPoZQ==')
    end

    it 'create consul_secret_key if enabled ACL' do
      allow(CloudConductor::Config.consul.options).to receive(:acl).and_return(true)

      expect(@history.consul_secret_key).to be_nil
      @history.send(:set_consul_secret_key)
      expect(@history.consul_secret_key).to eq('PDtYpNJ1wLvkSJw94SPoZQ==')
    end
  end

  describe '#set_version' do
    before do
      allow(@history).to receive(:set_version).and_call_original
    end

    it 'set version 1 when previous history does not exist' do
      @history.version = nil
      @history.send(:set_version)
      expect(@history.version).to eq(1)
    end

    it 'set new version when previous history already exists' do
      @history.version = nil
      blueprint.histories << FactoryGirl.build(:blueprint_history)
      blueprint.histories << FactoryGirl.build(:blueprint_history)
      @history.send(:set_version)
      expect(@history.version).to eq(3)
    end
  end

  describe '#as_json' do
    it 'contains status' do
      allow(@history).to receive(:status).and_return(:CREATE_COMPLETE)
      hash = @history.as_json
      expect(hash['status']).to eq(:CREATE_COMPLETE)
    end

    it 'doesn\'t contain parameters' do
      hash = @history.as_json
      expect(hash['parameters']).to be_nil
    end
  end

  describe '#status' do
    before do
      @history.pattern_snapshots << FactoryGirl.create(:pattern_snapshot, blueprint_history: @history)
      @history.pattern_snapshots << FactoryGirl.create(:pattern_snapshot, blueprint_history: @history)
      @history.pattern_snapshots << FactoryGirl.create(:pattern_snapshot, blueprint_history: @history)
      allow(@history.pattern_snapshots[0]).to receive(:status).and_return(:PROGRESS)
      allow(@history.pattern_snapshots[1]).to receive(:status).and_return(:PROGRESS)
      allow(@history.pattern_snapshots[2]).to receive(:status).and_return(:PROGRESS)
    end

    it 'return status that integrated status over all pattern_snapshots' do
      expect(@history.status).to eq(:PROGRESS)
    end

    it 'return :PROGRESS when least one pattern_snapshots has progress status' do
      allow(@history.pattern_snapshots[0]).to receive(:status).and_return(:CREATE_COMPLETE)

      expect(@history.status).to eq(:PROGRESS)
    end

    it 'return :CREATE_COMPLETE when all pattern_snapshots have CREATE_COMPLETE status' do
      allow(@history.pattern_snapshots[0]).to receive(:status).and_return(:CREATE_COMPLETE)
      allow(@history.pattern_snapshots[1]).to receive(:status).and_return(:CREATE_COMPLETE)
      allow(@history.pattern_snapshots[2]).to receive(:status).and_return(:CREATE_COMPLETE)

      expect(@history.status).to eq(:CREATE_COMPLETE)
    end

    it 'return error when least one image has error status' do
      allow(@history.pattern_snapshots[0]).to receive(:status).and_return(:CREATE_COMPLETE)
      allow(@history.pattern_snapshots[1]).to receive(:status).and_return(:PROGRESS)
      allow(@history.pattern_snapshots[2]).to receive(:status).and_return(:ERROR)

      expect(@history.status).to eq(:ERROR)
    end
  end

  describe '#build_pattern_snapshots' do
    it 'create pattern_snapshot from relation' do
      allow(@history).to receive(:build_pattern_snapshots).and_call_original
      allow_any_instance_of(PatternSnapshot).to receive(:freeze_pattern)
      blueprint.patterns << FactoryGirl.create(:pattern, :platform, project: project)
      blueprint.patterns << FactoryGirl.create(:pattern, :optional, project: project)
      @history.send(:build_pattern_snapshots)
      expect(@history.pattern_snapshots.size).to eq(2)
    end
  end
end
