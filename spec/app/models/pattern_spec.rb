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
describe Pattern do
  include_context 'default_resources'

  let(:cloned_path) { File.expand_path("./tmp/patterns/#{SecureRandom.uuid}") }

  it 'include PatternAccessor' do
    expect(Pattern).to be_include(PatternAccessor)
  end

  before do
    @pattern = Pattern.new
    @pattern.project = project
    @pattern.url = 'http://example.com/pattern.git'

    allow(@pattern).to receive(:freeze_pattern)
  end

  describe '#initialize' do
    it 'set protocol to git' do
      expect(@pattern.protocol).to eq('git')
    end
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @pattern.save! }.to change { Pattern.count }.by(1)
    end

    it 'will call freeze_pattern callback' do
      expect(@pattern).to receive(:freeze_pattern)
      @pattern.save!
    end
  end

  describe '#destroy' do
    it 'delete pattern record' do
      @pattern.save!
      expect { @pattern.destroy }.to change { Pattern.count }.by(-1)
    end

    it 'delete all catalogs records' do
      @pattern.catalogs << FactoryGirl.create(:catalog, blueprint: blueprint, pattern: @pattern)
      expect(@pattern.blueprints.size).to eq(1)
      expect { @pattern.destroy }.to change { Catalog.count }.by(-1)
    end

    it 'delete all pattern histories records' do
      @pattern.histories << FactoryGirl.create(:pattern_history, pattern: @pattern)
      expect(@pattern.histories.size).to eq(1)
      expect { @pattern.destroy }.to change { PatternHistory.count }.by(-1)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@pattern.valid?).to be_truthy
    end

    it 'returns false when project is unset' do
      @pattern.project = nil
      expect(@pattern.valid?).to be_falsey
    end

    it 'returns false when url is unset' do
      @pattern.url = nil
      expect(@pattern.valid?).to be_falsey
    end

    it 'returns false when url is invalid URL' do
      @pattern.url = 'invalid url'
      expect(@pattern.valid?).to be_falsey
    end
  end

  describe '#freeze_pattern' do
    before do
      allow(@pattern).to receive(:freeze_pattern).and_call_original
      allow(@pattern).to receive(:clone_repository).and_yield(cloned_path)
      allow(@pattern).to receive(:load_metadata).and_return({})
      allow(@pattern).to receive(:read_parameters).and_return({})
      allow(@pattern).to receive(:read_roles).and_return([])
    end

    it 'will call #clone_repository' do
      expect(@pattern).to receive(:clone_repository)
      @pattern.send(:freeze_pattern)
    end

    it 'will call #load_metadata' do
      expect(@pattern).to receive(:load_metadata)
      @pattern.send(:freeze_pattern)
    end

    it 'will call #read_parameters' do
      expect(@pattern).to receive(:read_parameters)
      @pattern.send(:freeze_pattern)
    end

    it 'will call #read_roles' do
      expect(@pattern).to receive(:read_roles)
      @pattern.send(:freeze_pattern)
    end
  end
end
