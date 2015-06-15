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
  include_context 'default_resources'

  before do
    @stack = Stack.new
    @stack.name = 'Test'
    @stack.pattern = pattern
    @stack.cloud = cloud
    @stack.environment = environment
  end

  describe '.in_progress' do
    it 'returns stacks in progress status' do
      stack = FactoryGirl.create(:stack, environment: environment, pattern: pattern, status: :PROGRESS)
      expect(Stack.in_progress).to include(stack)
      [:PENDING, :READY_FOR_CREATE, :READY_FOR_UPDATE, :ERROR, :CREATE_COMPLETE].each do |state|
        stack.update_columns(status: state)
        expect(Stack.in_progress).not_to include(stack)
      end
    end
  end

  describe '.created' do
    it 'returns stacks in progress status' do
      stack = FactoryGirl.create(:stack, environment: environment, pattern: pattern, status: :CREATE_COMPLETE)
      expect(Stack.created).to include(stack)
      [:PENDING, :PROGRESS, :READY_FOR_CREATE, :READY_FOR_UPDATE, :ERROR].each do |state|
        stack.update_columns(status: state)
        expect(Stack.created).not_to include(stack)
      end
    end
  end

  describe '#initialize' do
    it 'set default values to status, template_parameters and parameters' do
      expect(@stack.status).to eq(:PENDING)
      expect(@stack.template_parameters).to eq('{}')
      expect(@stack.parameters).to eq('{}')
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@stack.valid?).to be_truthy
    end

    it 'return true when name is not unique in two Clouds' do
      FactoryGirl.create(:stack, environment: environment, pattern: pattern, name: 'Test', cloud: FactoryGirl.create(:cloud, :openstack))
      expect(@stack.valid?).to be_truthy
    end

    it 'returns false when environment is unset' do
      @stack.environment = nil
      expect(@stack.valid?).to be_falsey
    end

    it 'returns false when pattern is unset' do
      @stack.pattern = nil
      expect(@stack.valid?).to be_falsey
    end

    it 'returns false when pattern status isn\'t CREATE_COMPLETE' do
      @stack.pattern.images << FactoryGirl.create(:image, status: :PROGRESS, pattern: @stack.pattern)
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

    it 'call #update_name callback' do
      expect(@stack).to receive(:update_name)
      @stack.valid?
    end
  end

  describe '#save' do
    before do
      allow(@stack).to receive(:create_stack)
      allow(@stack).to receive(:update_stack)
    end

    it 'create with valid parameters' do
      expect { @stack.save! }.to change { Stack.count }.by(1)
    end

    it 'call #create_stack callback when status is ready_for_create' do
      expect(@stack).to receive(:create_stack)
      @stack.status = :READY_FOR_CREATE
      @stack.save!
    end

    it 'call #create_stack callback when status is ready_for_update' do
      expect(@stack).to receive(:update_stack)
      @stack.status = :READY_FOR_UPDATE
      @stack.save!
    end

    it 'doesn\'t call #create_stack callback when status isn\'t ready_for_create' do
      expect(@stack).not_to receive(:create_stack)
      @stack.status = :PENDING
      @stack.save!
    end

    it 'doesn\'t call #create_stack callback when status isn\'t ready_for_update' do
      expect(@stack).not_to receive(:update_stack)
      @stack.status = :PENDING
      @stack.save!
    end
  end

  describe '#update_name' do
    it 'call Client#create_stack' do
      expect(@stack.name).to eq('Test')
      @stack.update_name
      expect(@stack.name).to eq("#{@stack.environment.system.name}-#{@stack.environment.id}-#{@stack.pattern.name}")
    end
  end

  describe '#create_stack' do
    before do
      allow(@stack).to receive_message_chain(:client, :create_stack)
    end

    it 'call Client#create_stack' do
      expect(@stack).to receive_message_chain(:client, :create_stack)
      @stack.create_stack
    end

    it 'update status to :PROGRESS if Client#create_stack hasn\'t error occurred' do
      @stack.status = :READY_FOR_CREATE
      @stack.create_stack

      expect(@stack.attributes['status']).to eq(:PROGRESS)
    end

    it 'update status to :ERROR if Client#create_stack raise error' do
      allow(@stack).to receive_message_chain(:client, :create_stack).and_raise
      @stack.status = :READY_FOR_CREATE
      @stack.create_stack

      expect(@stack.attributes['status']).to eq(:ERROR)
    end
  end

  describe '#update_stack' do
    before do
      allow(@stack).to receive_message_chain(:client, :update_stack)
    end

    it 'call Client#update_stack' do
      expect(@stack).to receive_message_chain(:client, :update_stack)
      @stack.update_stack
    end

    it 'update status to :ERROR if Client#update_stack raise error' do
      allow(@stack).to receive_message_chain(:client, :update_stack).and_raise(Net::OpenTimeout)
      @stack.status = :READY_FOR_UPDATE
      @stack.update_stack

      expect(@stack.attributes['status']).to eq(:ERROR)
    end
  end

  describe '#dup' do
    it 'duplicate all attributes in stack' do
      duplicated_stack = @stack.dup
      expect(duplicated_stack.template_parameters).to eq(@stack.template_parameters)
      expect(duplicated_stack.parameters).to eq(@stack.parameters)
    end

    it 'reset status to :PENDING' do
      duplicated_stack = @stack.dup
      expect(duplicated_stack.status).to eq(:PENDING)
    end
  end

  describe '#status' do
    before do
      @client = double(:client, get_stack_status: 'dummy')
      allow(@stack).to receive(:client).and_return(@client)
    end

    it 'return status without API request when status isn\'t progress' do
      expect(@client).not_to receive(:get_stack_status)

      @stack.status = :PENDING
      expect(@stack.status).to eq(:PENDING)

      @stack.status = :READY_FOR_CREATE
      expect(@stack.status).to eq(:READY_FOR_CREATE)

      @stack.status = :READY_FOR_UPDATE
      expect(@stack.status).to eq(:READY_FOR_UPDATE)

      @stack.status = :CREATE_COMPLETE
      expect(@stack.status).to eq(:CREATE_COMPLETE)

      @stack.status = :ERROR
      expect(@stack.status).to eq(:ERROR)
    end

    it 'call get_stack_status on adapter that related active cloud while progress' do
      expect(@client).to receive(:get_stack_status).with(@stack.name).and_return(:dummy)

      @stack.status = :PROGRESS
      expect(@stack.status).to eq(:dummy)
    end
  end

  describe '#events' do
    before do
      @client = double(:client, get_stack_events: [])
      allow(@stack).to receive(:client).and_return(@client)
    end

    it 'call get_stack_events on adapter that related active cloud' do
      expect(@stack).to receive_message_chain(:client, :get_stack_events).with(@stack.name).and_return([])
      expect(@stack.events).to eq([])
    end
  end

  describe '#outputs' do
    it 'call get_outputs on adapter that related active cloud' do
      expect(@stack).to receive_message_chain(:client, :get_outputs).with(@stack.name).and_return(key: 'value')
      expect(@stack.outputs).to eq(key: 'value')
    end
  end

  describe '#destroy' do
    before do
      allow(@stack).to receive(:destroy_stack)
    end

    it 'call #destroy_stack callback' do
      expect(@stack).to receive(:destroy_stack)
      @stack.status = :CREATE_COMPLETE
      @stack.destroy
    end

    it 'doesn\'t call #destroy_stack callback when status is pending' do
      expect(@stack).not_to receive(:destroy_stack)
      @stack.status = :PENDING
      @stack.destroy
    end

    it 'delete stack record' do
      @stack.save!
      expect { @stack.destroy }.to change { Stack.count }.by(-1)
    end
  end

  describe '#destroy_stack' do
    it 'call Client#destroy_stack on current adapter' do
      expect(@stack).to receive_message_chain(:client, :destroy_stack).with(@stack.name)
      @stack.destroy_stack
    end
  end

  describe '#payload' do
    it 'return hash that has pattern information and parameters of stack' do
      payload = @stack.payload
      expect(payload.keys).to eq([@stack.pattern.name])

      pattern_payload = payload[@stack.pattern.name]
      expect(pattern_payload.keys).to eq(%i(name type protocol url revision user_attributes config))

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
      @stack.status = :READY_FOR_CREATE
      expect(@stack.pending?).to be_falsey
      @stack.status = :PENDING
      expect(@stack.pending?).to be_truthy
    end
  end

  describe '#ready_for_create?' do
    it 'return boolean for status is ready_for_create' do
      expect(@stack.ready_for_create?).to be_falsey
      @stack.status = :READY_FOR_CREATE
      expect(@stack.ready_for_create?).to be_truthy
    end
  end

  describe '#ready_for_update?' do
    it 'return boolean for status is ready_for_update' do
      expect(@stack.ready_for_update?).to be_falsey
      @stack.status = :READY_FOR_UPDATE
      expect(@stack.ready_for_update?).to be_truthy
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
      @stack.pattern.type = 'platform'
      expect(@stack.platform?).to be_truthy
    end

    it 'return false if stack has optional pattern' do
      @stack.pattern.type = 'optional'
      expect(@stack.platform?).to be_falsey
    end
  end

  describe '#optional?' do
    it 'return true if stack has optional pattern' do
      @stack.pattern.type = 'optional'
      expect(@stack.optional?).to be_truthy
    end

    it 'return false if stack has platform pattern' do
      @stack.pattern.type = 'platform'
      expect(@stack.optional?).to be_falsey
    end
  end

  describe '#exists_on_cloud?' do
    it 'return true when target stack has been exist' do
      expect(@stack).to receive_message_chain(:client, :get_stack_status).with(@stack.name).and_return(:CREATE_COMPLETE)
      expect(@stack.exists_on_cloud?).to be_truthy
    end

    it 'return false when target stack has not been exist' do
      expect(@stack).to receive_message_chain(:client, :get_stack_status).with(@stack.name).and_return(:CREATE_COMPLETE).and_raise
      expect(@stack.exists_on_cloud?).to be_falsey
    end
  end
end
