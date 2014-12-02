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
  before do
    @system = FactoryGirl.build(:system)
    @system.stub(:serf).and_return(double('serf_client', call: nil))

    @application = Application.new
    @application.name = 'dummy'
    @application.system = @system
    @application.histories << FactoryGirl.build(:application_history)
  end

  describe '#save' do
    it 'create with valid parameters' do
      count = Application.count

      @application.save!

      expect(Application.count).to eq(count + 1)
    end
  end

  describe '#delete' do
    it 'delete all relational history' do
      @application.save!

      count = ApplicationHistory.count
      @application.destroy
      expect(ApplicationHistory.count).to eq(count - 1)
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

  describe '#latest' do
    it 'return latest ApplicationHistory' do
      @application.save!
      @application.histories << FactoryGirl.build(:application_history)
      latest = FactoryGirl.build(:application_history)
      @application.histories << latest

      expect(@application.latest).to eq(latest)
    end
  end

  describe '#latest_version' do
    it 'return latest ApplicationHistory version' do
      @application.save!
      @application.histories << FactoryGirl.build(:application_history)
      @application.histories << FactoryGirl.build(:application_history)

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
