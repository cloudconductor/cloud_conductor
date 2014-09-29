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
describe Stack do
  before do
    @pattern = FactoryGirl.create(:pattern)
    @image = FactoryGirl.create(:image)
    @image.status = :created
    @pattern.images.push(@image)

    @stack = Stack.new
    @stack.name = 'Test'
    @stack.template_parameters = '{}'
    @stack.parameters = '{ "key1": "value1" }'
    @stack.pattern = @pattern
    @stack.cloud = FactoryGirl.create(:cloud_aws)
    @stack.system = FactoryGirl.create(:system)
    @stack.status = :NOT_CREATED

    @client = double('client', create_stack: nil, get_stack_status: :dummy, destroy_stack: nil)
    @stack.cloud.stub(:client).and_return(@client)
  end

  it 'create with valid parameters' do
    count = Stack.count

    @stack.save!

    expect(Stack.count).to eq(count + 1)
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@stack.valid?).to be_truthy
    end

    it 'returns false when name is unset' do
      @stack.name = nil
      expect(@stack.valid?).to be_falsey

      @stack.name = ''
      expect(@stack.valid?).to be_falsey
    end

    it 'returns false when system is unset' do
      @stack.system = nil
      expect(@stack.valid?).to be_falsey
    end

    it 'returns false when cloud is unset' do
      @stack.cloud = nil
      expect(@stack.valid?).to be_falsey
    end

    it 'returns false when template_parameters is invalid JSON string' do
      @stack.template_parameters = '{'
      expect(@stack.valid?).to be_falsey
    end

    it 'returns false when parameters is invalid JSON string' do
      @stack.parameters = '{'
      expect(@stack.valid?).to be_falsey
    end

    it 'returns false when pattern status isn\'t created' do
      @image.status = :processing
      expect(@stack.valid?).to be_falsey
    end
  end

  describe '#before_create' do
    before do
      @template_parameters = JSON.parse @stack.template_parameters
    end

    it 'call create_stack on cloud' do
      @client.should_receive(:create_stack).with(@stack.name, @stack.pattern, @template_parameters)

      @stack.save!
    end

    it 'update status to :PROGRESS if Client#create_stack hasn\'t error occurred' do
      @client.stub(:create_stack)
      @stack.save!

      expect(@stack.attributes['status']).to eq(:PROGRESS)
    end

    it 'update status to :ERROR if Client#create_stack raise error' do
      @client.stub(:create_stack).and_raise
      @stack.save!

      expect(@stack.attributes['status']).to eq(:ERROR)
    end
  end

  describe '#dup' do
    it 'duplicate all attributes in stack without name and ip_address' do
      duplicated_stack = @stack.dup
      expect(duplicated_stack.template_parameters).to eq(@stack.template_parameters)
      expect(duplicated_stack.parameters).to eq(@stack.parameters)
    end

    it 'duplicate name with uuid to avoid unique constraint' do
      duplicated_stack = @stack.dup
      expect(duplicated_stack.name).not_to eq(@stack.name)
      expect(duplicated_stack.name).to match(/-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end
  end

  describe '#status' do
    it 'return status without API request when status isn\'t progress' do
      @client.should_not_receive(:get_stack_status)

      @stack.status = :NOT_CREATED
      expect(@stack.status).to eq(:NOT_CREATED)

      @stack.status = :CREATED
      expect(@stack.status).to eq(:CREATED)

      @stack.status = :ERROR
      expect(@stack.status).to eq(:ERROR)
    end

    it 'call get_stack_status on adapter that related active cloud while progress' do
      @client.should_receive(:get_stack_status).with(@stack.name).and_return(:dummy)

      @stack.status = :PROGRESS
      expect(@stack.status).to eq(:dummy)
    end
  end

  describe '#outputs' do
    it 'call get_outputs on adapter that related active cloud' do
      @stack.save!

      @client.should_receive(:get_outputs).with(@stack.name).and_return(key: 'value')

      expect(@stack.outputs).to eq(key: 'value')
    end
  end

  describe '.in_progress scope' do
    it 'returns stacks in progress status' do
      count = Stack.in_progress.count

      @stack.save!

      expect(Stack.in_progress.count).to eq(count + 1)

      @stack.status = :CREATED
      @stack.save!

      expect(Stack.in_progress.count).to eq(count)
    end
  end

  describe '#destroy' do
    it 'will delete stack record' do
      count = Stack.count
      @stack.save!
      @stack.destroy
      expect(Stack.count).to eq(count)
    end

    it 'will call destroy_stack method on current adapter' do
      @stack.save!

      @client.should_receive(:destroy_stack).with(@stack.name)

      @stack.destroy
    end
  end

  describe '#payload' do
    it 'return hash that has pattern information and parameters of stack' do
      payload = @stack.payload
      expect(payload.keys).to eq([@stack.pattern.name])

      pattern_payload = payload[@stack.pattern.name]
      expect(pattern_payload[:name]).to eq(@stack.pattern.name)
      expect(pattern_payload[:type]).to eq(@stack.pattern.type.to_s)
      expect(pattern_payload[:protocol]).to eq(@stack.pattern.protocol.to_s)
      expect(pattern_payload[:url]).to eq(@stack.pattern.url)
      expect(pattern_payload[:revision]).to eq(@stack.pattern.revision)
      expect(pattern_payload[:user_attributes]).to eq(JSON.parse(@stack.parameters, symbolize_names: true))
    end
  end
end
