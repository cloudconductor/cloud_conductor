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
    @system = FactoryGirl.create(:system)

    @application = Application.new
    @application.name = 'dummy'
    @application.system = @system

    @application.histories << ApplicationHistory.new
  end

  describe '#save' do
    it 'create with valid parameters' do
      count = Application.count

      @application.save!

      expect(Application.count).to eq(count + 1)
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
end
