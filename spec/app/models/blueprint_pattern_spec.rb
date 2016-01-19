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
describe BlueprintPattern do
  include_context 'default_resources'

  before do
    allow_any_instance_of(Project).to receive(:create_preset_roles)
  end

  describe '#valid?' do
    it 'returns true with blueprint and pattern' do
      relation = BlueprintPattern.new(blueprint: blueprint, pattern: pattern, platform: 'centos')
      expect(relation).to be_valid
    end

    it 'returns false without blueprint' do
      relation = BlueprintPattern.new(blueprint: nil, pattern: pattern, platform: 'centos')
      expect(relation).not_to be_valid
    end

    it 'returns false without pattern' do
      relation = BlueprintPattern.new(blueprint: blueprint, pattern: nil, platform: 'centos')
      expect(relation).not_to be_valid
    end

    it 'returns false without platform' do
      relation = BlueprintPattern.new(blueprint: blueprint, pattern: pattern, platform: nil)
      expect(relation).not_to be_valid
    end

    it 'returns false when platform is not family' do
      relation = BlueprintPattern.new(blueprint: blueprint, pattern: pattern, platform: 'testOS')
      expect(relation).not_to be_valid
    end
  end
end
