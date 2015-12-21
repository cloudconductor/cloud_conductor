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
describe Blueprint do
  include_context 'default_resources'

  before do
    @blueprint = FactoryGirl.build(:blueprint, project: project)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @blueprint.save! }.to change { Blueprint.count }.by(1)
    end

    it 'create with long text' do
      @blueprint.description = '*' * 256
      expect { @blueprint.save! }.to change { Blueprint.count }.by(1)
    end
  end

  describe '#destroy' do
    it 'delete blueprint record' do
      @blueprint.save!
      expect { @blueprint.destroy }.to change { Blueprint.count }.by(-1)
    end

    it 'delete all relations' do
      @blueprint.blueprint_patterns << FactoryGirl.create(:blueprint_pattern, blueprint: @blueprint, pattern: pattern)
      expect(@blueprint.patterns.size).to eq(1)
      expect { @blueprint.destroy }.to change { BlueprintPattern.count }.by(-1)
    end

    it 'delete all blueprint histories records' do
      @blueprint.histories << FactoryGirl.create(:blueprint_history, blueprint: @blueprint)
      expect(@blueprint.histories.size).to eq(1)
      expect { @blueprint.destroy }.to change { BlueprintHistory.count }.by(-1)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@blueprint.valid?).to be_truthy
    end

    it 'returns false when name is unset' do
      @blueprint.name = nil
      expect(@blueprint.valid?).to be_falsey

      @blueprint.name = ''
      expect(@blueprint.valid?).to be_falsey
    end

    it 'returns false when project is unset' do
      @blueprint.project = nil
      expect(@blueprint.valid?).to be_falsey
    end

    it 'returns false when name is duplicated' do
      FactoryGirl.create(:blueprint, name: 'dummy')
      @blueprint.name = 'dummy'
      expect(@blueprint.valid?).to be_falsey
    end
  end

  describe '#can_build?' do
    it 'returns false when patterns is empty' do
      expect(@blueprint).not_to be_can_build
    end

    it 'returns true when patterns has platform pattern' do
      @blueprint.patterns << FactoryGirl.build(:pattern, :platform, project: project)
      expect(@blueprint).to be_can_build
    end

    it 'returns true when patterns hasn\'t platform pattern' do
      @blueprint.patterns << FactoryGirl.build(:pattern, :optional, project: project)
      @blueprint.patterns << FactoryGirl.build(:pattern, :optional, project: project)
      expect(@blueprint).not_to be_can_build
    end
  end
end
