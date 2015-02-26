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
module CloudConductor
  describe Client do
    include_context 'default_resources'

    before do
      allow_any_instance_of(Adapters::AWSAdapter).to receive(:get_availability_zones).and_return(['ap-southeast-2a'])
      allow_any_instance_of(Adapters::OpenStackAdapter).to receive(:get_availability_zones).and_return(['nova'])
      allow_any_instance_of(Adapters::DummyAdapter).to receive(:get_availability_zones).and_return(['dummy'])
      allow(CloudConductor::Duplicators).to receive(:increase_instance).and_return('{ "dummy": "dummy_value" }')
      @client = Client.new cloud
    end

    describe '#new' do
      it 'returns initialized client with aws adapter' do
        cloud_aws = FactoryGirl.create(:cloud_aws)
        client = Client.new cloud_aws
        expect(client.type).to eq(:aws)
        expect(client.adapter.class).to eq(Adapters::AWSAdapter)
      end

      it 'returns initialized client with openstack adapter' do
        cloud_openstack = FactoryGirl.create(:cloud_openstack)
        client = Client.new cloud_openstack
        expect(client.type).to eq(:openstack)
        expect(client.adapter.class).to eq(Adapters::OpenStackAdapter)
      end
    end

    describe '#create_stack' do
      before do
        allow(pattern).to receive(:clone_repository).and_yield('/tmp/patterns')
        allow(@client).to receive_message_chain(:open, :read).and_return('{ "dummy": "dummy_value" }')
      end

      it 'call adapter#create_stack with same arguments without pattern' do
        expect(@client.adapter).to receive(:create_stack).with('stack_name', anything, kind_of(Hash), kind_of(Hash))
        @client.create_stack 'stack_name', pattern, {}, {}
      end

      it 'call adapter#create_stack with template.json in repository' do
        expect(@client.adapter).to receive(:create_stack).with(anything, '{ "dummy": "dummy_value" }', anything, anything)
        @client.create_stack 'stack_name', pattern, {}, {}
      end

      it 'add ImageId/Image pair to parameter-hash' do
        image1 = FactoryGirl.create(:image, pattern: pattern, cloud: cloud)
        image2 = FactoryGirl.create(:image, pattern: pattern, cloud: cloud)
        expected_parameters = satisfy do |parameters|
          expect(parameters.keys.count { |key| key.match(/[a-z0-9_]*ImageId/) }).to eq(2)

          expect(parameters["#{image1.role}ImageId"]).to eq(image1.image)
          expect(parameters["#{image2.role}ImageId"]).to eq(image2.image)
        end

        expect(@client.adapter).to receive(:create_stack).with(anything, anything, expected_parameters, anything)
        @client.create_stack 'stack_name', pattern, {}, {}
      end

      it 'use key of ImageId that remove special characters from image.role' do
        FactoryGirl.create(:image, pattern: pattern, cloud: cloud, role: 'web, ap, db')
        expected_parameters = satisfy do |parameters|
          expect(parameters.keys).to be_include('webapdbImageId')
        end

        expect(@client.adapter).to receive(:create_stack).with(anything, anything, expected_parameters, anything)
        @client.create_stack 'stack_name', pattern, {}, {}
      end
    end

    describe '#get_stack_status' do
      it 'call adapter#get_stack_status with same arguments' do
        expect(@client.adapter).to receive(:get_stack_status).with('stack_name', kind_of(Hash))
        @client.get_stack_status 'stack_name'
      end
    end

    describe '#get_outputs' do
      it 'call adapter#get_outputs with same arguments' do
        expect(@client.adapter).to receive(:get_outputs).with('stack_name', kind_of(Hash))
        @client.get_outputs 'stack_name'
      end
    end

    describe '#destroy_stack' do
      it 'call adapter#destroy_stack with same arguments' do
        expect(@client.adapter).to receive(:destroy_stack).with('stack_name', kind_of(Hash))
        @client.destroy_stack 'stack_name'
      end
    end
  end
end
