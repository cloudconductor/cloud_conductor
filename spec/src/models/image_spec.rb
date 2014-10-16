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
describe Image do
  before do
    @image = Image.new
    @image.role = 'dummy'
  end

  it 'create with valid parameters' do
    count = Image.count

    @image.save!

    expect(Image.count).to eq(count + 1)
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@image.valid?).to be_truthy

      @image.role = 'test'
      expect(@image.valid?).to be_truthy
    end

    it 'returns false when role is unset' do
      @image.role = nil
      expect(@image.valid?).to be_falsey

      @image.role = ''
      expect(@image.valid?).to be_falsey
    end

    it 'returns false when role contains hyphen or underscore character' do
      @image.role = 'dummy-role'
      expect(@image.valid?).to be_falsey

      @image.role = 'dummy_role'
      expect(@image.valid?).to be_falsey
    end
  end

  describe '#status' do
    it 'returns :PROGRESS status when initialized' do
      expect(@image.status).to eq(:PROGRESS)
    end

    it 'returns image status as symbol' do
      @image.status = 'sample'
      expect(@image.status).to eq(:sample)
    end
  end
end
