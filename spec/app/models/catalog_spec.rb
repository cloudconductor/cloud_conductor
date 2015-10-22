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
describe Catalog do
  include_context 'default_resources'

  describe '#valid?' do
    it 'returns true with blueprint and pattern' do
      catalog = Catalog.new(blueprint: blueprint, pattern: pattern)
      expect(catalog).to be_valid
    end

    it 'returns false without blueprint' do
      catalog = Catalog.new(blueprint: nil, pattern: pattern)
      expect(catalog).not_to be_valid
    end

    it 'returns false without pattern' do
      catalog = Catalog.new(blueprint: blueprint, pattern: nil)
      expect(catalog).not_to be_valid
    end
  end

  describe '#initialize' do
    it 'set os_version to default' do
      expect(Catalog.new.os_version).to eq('default')
    end
  end
end
