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
describe OperatingSystem do
  before do
    @operating_system = OperatingSystem.new
    @operating_system.name = 'dummy_name'
  end

  it 'create with valid parameters' do
    count = OperatingSystem.count

    @operating_system.save!

    expect(OperatingSystem.count).to eq(count + 1)
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@operating_system.valid?).to be_truthy

      @operating_system.name = 'test_name'
      expect(@operating_system.valid?).to be_truthy
    end

    it 'returns false when name is unset' do
      @operating_system.name = nil
      expect(@operating_system.valid?).to be_falsey

      @operating_system.name = ''
      expect(@operating_system.valid?).to be_falsey
    end

    it 'returns false when name contains hyphen character' do
      @operating_system.name = 'dummy-name'
      expect(@operating_system.valid?).to be_falsey
    end
  end
end
