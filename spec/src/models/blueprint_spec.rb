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
  before do
    @blueprint = Blueprint.new
    @blueprint.name = 'test'
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @blueprint.save! }.to change { Blueprint.count }.by(1)
    end
  end

  describe '#destroy' do
    it 'delete blueprint record' do
      @blueprint.save!
      expect { @blueprint.destroy }.to change { Blueprint.count }.by(-1)
    end

    it 'delete all pattern records' do
      FactoryGirl.create(:pattern, :platform, blueprint: @blueprint)
      FactoryGirl.create(:pattern, :platform, blueprint: @blueprint)

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
  end
end
