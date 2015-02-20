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
    @blueprint = Blueprint.new
    @blueprint.name = 'test'
    @blueprint.project = project
    @blueprint.patterns << pattern

    allow(@blueprint).to receive(:update_consul_secret_key)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @blueprint.save! }.to change { Blueprint.count }.by(1)
    end

    it 'call #update_consul_secret_key callback' do
      expect(@blueprint).to receive(:update_consul_secret_key)
      @blueprint.save!
    end
  end

  describe '#destroy' do
    it 'delete blueprint record' do
      @blueprint.save!
      expect { @blueprint.destroy }.to change { Blueprint.count }.by(-1)
    end

    it 'delete all pattern records' do
      @blueprint.patterns.delete_all
      @blueprint.patterns << FactoryGirl.create(:pattern, :platform, blueprint: @blueprint)
      @blueprint.patterns << FactoryGirl.create(:pattern, :platform, blueprint: @blueprint)

      expect(@blueprint.patterns.size).to eq(2)
      expect { @blueprint.destroy }.to change { Pattern.count }.by(-2)
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

    it 'returns false when patterns is empty' do
      @blueprint.patterns = []
      expect(@blueprint.valid?).to be_falsey
    end
  end

  describe '#update_consul_secret_key' do
    before do
      allow(@blueprint).to receive(:update_consul_secret_key).and_call_original
      allow(@blueprint).to receive(:systemu).with('consul keygen').and_return([double('status', 'success?' => true), 'dummy key', ''])
    end

    it 'create consul_secret_key if enabled ACL' do
      allow(CloudConductor::Config.consul.options).to receive(:acl).and_return(true)

      expect(@blueprint.consul_secret_key).to be_nil
      @blueprint.send(:update_consul_secret_key)
      expect(@blueprint.consul_secret_key).to eq('dummy key')
    end

    it 'set empty string to consul_secret_key if disabled ACL' do
      allow(CloudConductor::Config.consul.options).to receive(:acl).and_return(false)

      expect(@blueprint.consul_secret_key).to be_nil
      @blueprint.send(:update_consul_secret_key)
      expect(@blueprint.consul_secret_key).to be_empty
    end
  end
end
