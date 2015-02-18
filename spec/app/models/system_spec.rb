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
    @system = System.new
    @system.project = project
    @system.name = 'test'
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @system.save! }.to change { System.count }.by(1)
    end
  end

  describe '#destroy' do
    it 'delete system record' do
      @system.save!
      expect { @system.destroy }.to change { System.count }.by(-1)
    end

    it 'delete all application records' do
      @system.applications << FactoryGirl.create(:application, system: @system)
      @system.applications << FactoryGirl.create(:application, system: @system)

      expect(@system.applications.size).to eq(2)
      expect { @system.destroy }.to change { Application.count }.by(-2)
    end

    it 'delete all environment records' do
      Environment.skip_callback :destroy, :before, :destroy_stacks

      @system.environments << FactoryGirl.create(:environment, system: @system)
      @system.environments << FactoryGirl.create(:environment, system: @system)

      expect(@system.environments.size).to eq(2)
      expect { @system.destroy }.to change { Environment.count }.by(-2)

      Environment.set_callback :destroy, :before, :destroy_stacks, unless: -> { stacks.empty? }
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
end
