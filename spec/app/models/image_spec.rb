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
  include_context 'default_resources'

  before do
    @image = Image.new
    @image.role = 'dummy'
    @image.cloud = cloud
    @image.pattern = pattern
    @image.base_image = base_image
    @image.image = 'dummy_image_id'
  end

  describe '#initialize' do
    it 'set default status' do
      expect(@image.status).to eq(:PROGRESS)
    end
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @image.save! }.to change { Image.count }.by(1)
    end

    it 'create with long text' do
      @image.message = '*' * 256
      @image.save!
    end
  end

  describe '#status' do
    it 'returns image status as symbol' do
      @image.status = 'sample'
      expect(@image.status).to be_a(Symbol)
    end
  end

  describe '#update_name' do
    it 'update name by base_image and role' do
      splitter = '----'
      @image.send(:update_name)
      expect(@image.name).to eq("#{@image.base_image.name}#{splitter}#{@image.role}")
    end

    it 'update name by base_image and multiple roles' do
      splitter = '----'
      @image.role = 'web, ap'
      @image.send(:update_name)
      expect(@image.name).to eq("#{@image.base_image.name}#{splitter}web-ap")
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@image.valid?).to be_truthy
    end

    it 'returns false when pattern is unset' do
      @image.pattern = nil
      expect(@image.valid?).to be_falsey
    end

    it 'returns false when cloud is unset' do
      @image.cloud = nil
      expect(@image.valid?).to be_falsey
    end

    it 'returns false when base_image is unset' do
      @image.base_image = nil
      expect(@image.valid?).to be_falsey
    end

    it 'returns false when role is unset' do
      @image.role = nil
      expect(@image.valid?).to be_falsey

      @image.role = ''
      expect(@image.valid?).to be_falsey
    end
  end

  describe '#destroy_image' do
    it 'call client#destroy_image with image id' do
      allow(@image).to receive_message_chain(:cloud, :client, :destroy_image).with('dummy_image_id')
      @image.destroy_image
    end
  end
end
