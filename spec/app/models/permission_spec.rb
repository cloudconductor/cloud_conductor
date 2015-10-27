# -*- coding: utf-8 -*-
# Copyright 2015 TIS Inc.
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
#
describe Permission do
  include_context 'default_resources'

  before do
    @permission = Permission.new
    @permission.model = 'test'
    @permission.action = 'create'
    @permission.role = role
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @permission.save! }.to change { Permission.count }.by(1)
    end
  end

  describe '#destroy' do
    it 'delete permission record' do
      @permission.save!
      expect { @permission.destroy }.to change { Permission.count }.by(-1)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@permission.valid?).to be_truthy
    end

    it 'returns false when role is unset' do
      @permission.role = nil
      expect(@permission.valid?).to be_falsey
    end

    it 'returns false when model is unset' do
      @permission.model = nil
      expect(@permission.valid?).to be_falsey
    end

    it 'returns false when action is unset' do
      @permission.action = nil
      expect(@permission.valid?).to be_falsey
    end
  end
end
