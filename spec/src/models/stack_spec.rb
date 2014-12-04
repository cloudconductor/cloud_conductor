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
    @pattern = FactoryGirl.build(:pattern)
    @image = FactoryGirl.build(:image)
    @image.status = :CREATE_COMPLETE
    @pattern.images.push(@image)
    @cloud = FactoryGirl.create(:cloud_aws)

    @stack = Stack.new
    @stack.name = 'Test'
    @stack.template_parameters = '{}'
    @stack.parameters = '{ "key1": "value1" }'
    @stack.pattern = @pattern
    @stack.cloud = @cloud
    @stack.system = FactoryGirl.build(:system)

    @client = double('client', create_stack: nil, get_stack_status: :dummy, destroy_stack: nil)
    @stack.cloud.stub(:client).and_return(@client)
  end

  describe '.created' do
    it 'return created stacks' do
      system = FactoryGirl.create(:system)
      _stack1 = FactoryGirl.create(:stack, system: system, status: :PENDING)
      stack2 = FactoryGirl.create(:stack, system: system, status: :CREATE_COMPLETE)
      _stack3 = FactoryGirl.create(:stack, system: system, status: :PENDING)
      stack4 = FactoryGirl.create(:stack, system: system, status: :CREATE_COMPLETE)

      _stack5 = FactoryGirl.create(:stack, status: :CREATE_COMPLETE)

      expect(system.stacks.created).to eq([stack2, stack4])
    end
  end

  it 'create with valid parameters' do
    count = Stack.count

    @stack.save!

    expect(Stack.count).to eq(count + 1)
  end

  describe '#initialize' do
    it 'set default values to status, template_parameters and parameters' do
      stack = Stack.new
      expect(stack.status).to eq(:PENDING)
      expect(stack.template_parameters).to eq('{}')
      expect(stack.parameters).to eq('{}')
    end
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

    it 'return false when name is not unique in Cloud' do
      stack = Stack.new
      stack.name = 'Test'
      stack.template_parameters = '{}'
      stack.parameters = '{ "key1": "value1" }'
      stack.pattern = @pattern
      stack.system = FactoryGirl.create(:system)
      stack.cloud = FactoryGirl.create(:cloud_openstack)
      stack.cloud.stub(:client).and_return(@client)
      stack.save!

      expect(@stack.valid?).to be_truthy

      stack.cloud = @cloud
      stack.cloud.stub(:client).and_return(@client)
      stack.save!
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

    it 'returns false when pattern is unset' do
      @stack.pattern = nil
      expect(@stack.valid?).to be_falsey
    end

    it 'returns false when pattern status isn\'t CREATE_COMPLETE' do
      @image.status = :PROGRESS
      expect(@stack.valid?).to be_falsey
    end
  end

  describe '#before_create' do
    before do
      @template_parameters = JSON.parse @stack.template_parameters
    end

    it 'call create_stack on cloud when ready status' do
      expected_parameters = @template_parameters
      expected_parameters.deep_merge!(dummy: 'value')
      @client.should_receive(:create_stack).with(@stack.name, @stack.pattern, expected_parameters)

      @stack.status = :READY
      @stack.save!
    end

    it 'doesn\'t call create_stack on cloud when pending status' do
      @client.should_not_receive(:create_stack)

      @stack.status = :PENDING
      @stack.save!
    end

    it 'update status to :PROGRESS if Client#create_stack hasn\'t error occurred' do
      @client.stub(:create_stack)
      @stack.status = :READY
      @stack.save!

      expect(@stack.attributes['status']).to eq(:PROGRESS)
    end

    it 'update status to :ERROR if Client#create_stack raise error' do
      @client.stub(:create_stack).and_raise
      @stack.status = :READY
      @stack.save!

      expect(@stack.attributes['status']).to eq(:ERROR)
    end
  end

  describe '#dup' do
    it 'duplicate all attributes in stack without name' do
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

      @stack.status = :PENDING
      expect(@stack.status).to eq(:PENDING)

      @stack.status = :READY
      expect(@stack.status).to eq(:READY)

      @stack.status = :CREATE_COMPLETE
      expect(@stack.status).to eq(:CREATE_COMPLETE)

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
      @stack.status = :READY
      @stack.save!

      expect(Stack.in_progress.count).to eq(count + 1)

      @stack.status = :CREATE_COMPLETE
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
      @stack.status = :CREATE_COMPLETE
      @stack.save!

      @client.should_receive(:destroy_stack).with(@stack.name)

      @stack.destroy
    end

    it 'won\'t call destroy_stack method on current adapter if stack has pending status' do
      @stack.status = :PENDING
      @stack.save!

      @client.should_not_receive(:destroy_stack)

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

  describe '#pending?' do
    it 'return boolean for status is pending' do
      @stack.status = :READY
      expect(@stack.pending?).to be_falsey
      @stack.status = :PENDING
      expect(@stack.pending?).to be_truthy
    end
  end

  describe '#ready?' do
    it 'return boolean for status is ready' do
      expect(@stack.ready?).to be_falsey
      @stack.status = :READY
      expect(@stack.ready?).to be_truthy
    end
  end

  describe '#progress?' do
    it 'return boolean for status is progress' do
      expect(@stack.progress?).to be_falsey
      @stack.status = :PROGRESS
      expect(@stack.progress?).to be_truthy
    end
  end

  describe '#create_complete?' do
    it 'return boolean for status is create_complete' do
      expect(@stack.create_complete?).to be_falsey
      @stack.status = :CREATE_COMPLETE
      expect(@stack.create_complete?).to be_truthy
    end
  end

  describe '#error?' do
    it 'return boolean for status is error' do
      expect(@stack.error?).to be_falsey
      @stack.status = :ERROR
      expect(@stack.error?).to be_truthy
    end
  end

  describe '#platform?' do
    it 'return true if stack has platform pattern' do
      @stack.pattern.type = :platform
      expect(@stack.platform?).to be_truthy
    end

    it 'return false if stack has optional pattern' do
      @stack.pattern.type = :optional
      expect(@stack.platform?).to be_falsey
    end
  end

  describe '#optional?' do
    it 'return true if stack has optional pattern' do
      @stack.pattern.type = :optional
      expect(@stack.optional?).to be_truthy
    end

    it 'return false if stack has platform pattern' do
      @stack.pattern.type = :platform
      expect(@stack.optional?).to be_falsey
    end
  end

  describe '#exist?' do
    it 'return true when target stack has been exist' do
      @client.stub(:get_stack_status).with(@stack.name).and_return(:CREATE_COMPLETE)
      expect(@stack.exist?).to be_truthy
    end

    it 'return false when target stack has not been exist' do
      @client.stub(:get_stack_status).with(@stack.name).and_raise
      expect(@stack.exist?).to be_falsey
    end
  end
end
