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
describe ApplicationHistory do
  before do
    @application = FactoryGirl.create(:application)

    @history = ApplicationHistory.new
    @history.application = @application
    @history.uri = 'http://example.com/'
    @history.parameters = '{ "dummy": "value" }'
  end

  describe '#save' do
    it 'create with valid parameters' do
      count = ApplicationHistory.count

      @history.save!

      expect(ApplicationHistory.count).to eq(count + 1)
    end

    it 'assign version on first history automatically when version does not specified' do
      @history.version = nil
      @history.save!

      expect(@history.version).to eq(1)
    end

    it 'assign version on second or later history automatically when version does not specified' do
      FactoryGirl.create(:application_history, application: @application)
      FactoryGirl.create(:application_history, application: @application)

      @history.version = nil
      @history.save!

      expect(@history.version).to eq(3)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@history.valid?).to be_truthy
    end

    it 'returns false when application is unset' do
      @history.application = nil
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when uri is unset' do
      @history.uri = nil
      expect(@history.valid?).to be_falsey

      @history.uri = ''
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when uri is invalid URI' do
      @history.uri = 'dummy'
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when parameters is invalid JSON' do
      @history.parameters = 'dummy'
      expect(@history.valid?).to be_falsey
    end
  end
end
