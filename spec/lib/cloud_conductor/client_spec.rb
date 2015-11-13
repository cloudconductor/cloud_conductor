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
      allow_any_instance_of(Adapters::AWSAdapter).to receive(:availability_zones).and_return(['ap-southeast-2a'])
      allow_any_instance_of(Adapters::OpenStackAdapter).to receive(:availability_zones).and_return(['nova'])
      allow_any_instance_of(Adapters::DummyAdapter).to receive(:availability_zones).and_return(['dummy'])
      allow(CloudConductor::Converter::Duplicators).to receive(:increase_instance).and_return('{ "dummy": "dummy_value" }')
      allow(CloudConductor::Converter).to receive_message_chain(:new, :update_cluster_addresses).and_return('{ "dummy": "dummy_value" }')
      @client = Client.new cloud
    end

    describe '#new' do
      it 'returns initialized client with aws adapter' do
        attributes = %w(key secret entry_point)
        expect(CloudConductor::Adapters::AWSAdapter).to receive(:new).with(hash_including(*attributes)).and_call_original
        cloud_aws = FactoryGirl.create(:cloud, :aws)
        client = Client.new cloud_aws
        expect(client.type).to eq('aws')
        expect(client.adapter.class).to eq(Adapters::AWSAdapter)
      end

      it 'returns initialized client with openstack adapter' do
        attributes = %w(key secret entry_point tenant_name)
        expect(CloudConductor::Adapters::OpenStackAdapter).to receive(:new).with(hash_including(*attributes)).and_call_original
        cloud_openstack = FactoryGirl.create(:cloud, :openstack)
        client = Client.new cloud_openstack
        expect(client.type).to eq('openstack')
        expect(client.adapter.class).to eq(Adapters::OpenStackAdapter)
      end
    end

    describe '#create_stack' do
      before do
        allow(pattern_snapshot).to receive(:clone_repository).and_yield('/tmp/patterns')
        allow(@client).to receive_message_chain(:open, :read).and_return('{ "dummy": "dummy_value" }')
      end

      it 'call adapter#create_stack with same arguments without pattern' do
        expect(@client.adapter).to receive(:create_stack).with('stack_name', anything, kind_of(Hash))
        @client.create_stack 'stack_name', pattern_snapshot, {}
      end

      it 'call adapter#create_stack with template.json in repository' do
        expect(@client.adapter).to receive(:create_stack).with(anything, '{ "dummy": "dummy_value" }', anything)
        @client.create_stack 'stack_name', pattern_snapshot, {}
      end

      it 'add ImageId/Image pair to parameter-hash' do
        image1 = pattern_snapshot.images.first
        image2 = FactoryGirl.create(:image, pattern_snapshot: pattern_snapshot, cloud: cloud)
        expected_parameters = satisfy do |parameters|
          expect(parameters.keys.count { |key| key.match(/[a-z0-9_]*ImageId/) }).to eq(2)

          expect(parameters["#{image1.role.camelize}ImageId"]).to eq(image1.image)
          expect(parameters["#{image2.role.camelize}ImageId"]).to eq(image2.image)
        end

        expect(@client.adapter).to receive(:create_stack).with(anything, anything, expected_parameters)
        @client.create_stack 'stack_name', pattern_snapshot, {}
      end

      it 'use key of ImageId that remove special characters from image.role' do
        FactoryGirl.create(:image, pattern_snapshot: pattern_snapshot, cloud: cloud, role: 'web, ap, db')
        expected_parameters = satisfy do |parameters|
          expect(parameters.keys).to be_include('WebApDbImageId')
        end

        expect(@client.adapter).to receive(:create_stack).with(anything, anything, expected_parameters)
        @client.create_stack 'stack_name', pattern_snapshot, {}
      end
    end

    describe '#update_stack' do
      before do
        allow(pattern_snapshot).to receive(:clone_repository).and_yield('/tmp/patterns')
        allow(@client).to receive_message_chain(:open, :read).and_return('{ "dummy": "dummy_value" }')
      end

      it 'call adapter#update_stack with same arguments without pattern' do
        expect(@client.adapter).to receive(:update_stack).with('stack_name', anything, kind_of(Hash))
        @client.update_stack 'stack_name', pattern_snapshot, {}
      end

      it 'call adapter#update_stack with template.json in repository' do
        expect(@client.adapter).to receive(:update_stack).with(anything, '{ "dummy": "dummy_value" }', anything)
        @client.update_stack 'stack_name', pattern_snapshot, {}
      end

      it 'add ImageId/Image pair to parameter-hash' do
        image1 = pattern_snapshot.images.first
        image2 = FactoryGirl.create(:image, pattern_snapshot: pattern_snapshot, cloud: cloud)
        expected_parameters = satisfy do |parameters|
          expect(parameters.keys.count { |key| key.match(/[a-zA-Z0-9_]*ImageId/) }).to eq(2)
          expect(parameters["#{image1.role.camelize}ImageId"]).to eq(image1.image)
          expect(parameters["#{image2.role.camelize}ImageId"]).to eq(image2.image)
        end

        expect(@client.adapter).to receive(:update_stack).with(anything, anything, expected_parameters)
        @client.update_stack 'stack_name', pattern_snapshot, {}
      end

      it 'use key of ImageId that remove special characters from image.role' do
        FactoryGirl.create(:image, pattern_snapshot: pattern_snapshot, cloud: cloud, role: 'web, ap, db')
        expected_parameters = satisfy do |parameters|
          expect(parameters.keys).to be_include('WebApDbImageId')
        end

        expect(@client.adapter).to receive(:update_stack).with(anything, anything, expected_parameters)
        @client.update_stack 'stack_name', pattern_snapshot, {}
      end
    end

    describe '#get_stack_status' do
      it 'call adapter#get_stack_status with same arguments' do
        expect(@client.adapter).to receive(:get_stack_status).with('stack_name')
        @client.get_stack_status 'stack_name'
      end
    end

    describe '#get_stack_events' do
      it 'call adapter#get_stack_events with same arguments' do
        expect(@client.adapter).to receive(:get_stack_events).with('stack_name')
        @client.get_stack_events 'stack_name'
      end
    end

    describe '#get_outputs' do
      it 'call adapter#get_outputs with same arguments' do
        expect(@client.adapter).to receive(:get_outputs).with('stack_name')
        @client.get_outputs 'stack_name'
      end
    end

    describe '#destroy_stack' do
      it 'call adapter#destroy_stack with same arguments' do
        expect(@client.adapter).to receive(:destroy_stack).with('stack_name')
        @client.destroy_stack 'stack_name'
      end
    end

    describe '#destroy_image' do
      it 'call adapter#destroy_image with image_id' do
        expect(@client.adapter).to receive(:destroy_image).with(1)
        @client.destroy_image 1
      end
    end

    describe '#post_process' do
      it 'call adapter#post_process' do
        expect(@client.adapter).to receive(:post_process)
        @client.post_process
      end
    end
  end
end
