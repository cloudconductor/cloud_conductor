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
describe Application do
  include_context 'default_resources'

  before do
    @system = System.eager_load(:project).find(system)
    @application = FactoryGirl.build(:application, system: @system)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @application.save! }.to change { Application.count }.by(1)
    end

    it 'create with long text' do
      @application.description = '*' * 256
      @application.save!
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@application.valid?).to be_truthy
    end

    it 'returns false when name is unset' do
      @application.name = nil
      expect(@application.valid?).to be_falsey

      @application.name = ''
      expect(@application.valid?).to be_falsey
    end

    it 'returns false when system is unset' do
      @application.system = nil
      expect(@application.valid?).to be_falsey
    end
  end

  describe '#destroy' do
    it 'delete application record' do
      @application.save!
      expect { @application.destroy }.to change { Application.count }.by(-1)
    end

    it 'delete all relational history' do
      @application.histories << FactoryGirl.build(:application_history, application: @application)
      @application.histories << FactoryGirl.build(:application_history, application: @application)
      @application.save!

      expect { @application.destroy }.to change { ApplicationHistory.count }.by(-2)
    end
  end

  describe '#latest' do
    it 'return latest ApplicationHistory' do
      @application.histories << FactoryGirl.build(:application_history, application: @application)

      latest = FactoryGirl.build(:application_history, application: @application)
      @application.histories << latest
      @application.save!

      expect(@application.latest).to eq(latest)
    end
  end

  describe '#latest_version' do
    it 'return latest ApplicationHistory version' do
      @application.histories << FactoryGirl.create(:application_history, application: @application)
      @application.histories << FactoryGirl.create(:application_history, application: @application)
      @application.save!

      expect(@application.latest_version).to match(/\d{8}-\d{3}/)
    end
  end

  describe '#dup' do
    it 'return duplicated application without system attributes' do
      application = @application.dup
      expect(application.name).to eq(@application.name)
      expect(application.system).to be_nil
    end
  end
end
