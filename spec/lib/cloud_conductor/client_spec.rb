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
        @name = 'stack_name'
        @cloud = FactoryGirl.create(:cloud_aws)
        @operating_system = FactoryGirl.create(:operating_system, name: 'centos')
        @pattern = FactoryGirl.create(:pattern)

        @parameters = {}
        @client = Client.new @cloud

        path = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}")
        allow(@pattern).to receive(:clone_repository).and_yield(path)
        @pattern.images << FactoryGirl.create(:image, cloud: @cloud, operating_system: @operating_system)

        @template_content = '{ "dummy": "dummy_value" }'
        allow(@client).to receive_message_chain(:open, :read).and_return(@template_content)

        allow_any_instance_of(Adapters::AWSAdapter).to receive(:create_stack)
      end

      it 'call adapter#create_stack with same arguments without pattern' do
        expect_any_instance_of(Adapters::AWSAdapter).to receive(:create_stack)
          .with(kind_of(String), anything, kind_of(Hash), kind_of(Hash))

        @client.create_stack @name, @pattern, @parameters
      end

      it 'will clone repository' do
        path = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}")
        expect(@pattern).to receive(:clone_repository).and_yield(path)

        @client.create_stack @name, @pattern, @parameters
      end

      it 'will load template.json in repository' do
        path_pattern = %r{/tmp/patterns/[a-f0-9-]{36}/template\.json}

        expect(@client).to receive(:open).with(path_pattern) do
          double('file').tap do |stub|
            expect(stub).to receive(:read).and_return('{}')
          end
        end

        @client.create_stack @name, @pattern, @parameters
      end

      it 'will get images to suit conditions that has been registered in pattern' do
        @client.create_stack @name, @pattern, @parameters
        result = @parameters.select { |key, _| !key.to_s.match(/[a-z0-9_]*ImageId/).nil? }
        expect(result.size).to eq(1)
      end

      it 'remove operating_system from parameter-hash' do
        expect_any_instance_of(Adapters::AWSAdapter).to receive(:create_stack).with(anything, anything, hash_excluding(:operating_system), anything)

        client = Client.new @cloud
        allow(client).to receive_message_chain(:open, :read).and_return(@template_content)
        client.create_stack @name, @pattern, @parameters
      end

      it 'add ImageId/Image pair to parameter-hash' do
        @pattern.images << FactoryGirl.create(:image, cloud: @cloud, operating_system: @operating_system)

        expected_parameters = satisfy do |parameters|
          @pattern.images.all? do |image|
            parameters["#{image.role}ImageId"] == image.image
          end
        end

        expect_any_instance_of(Adapters::AWSAdapter).to receive(:create_stack).with(anything, anything, expected_parameters, anything)

        client = Client.new @cloud
        allow(client).to receive_message_chain(:open, :read).and_return(@template_content)
        client.create_stack @name, @pattern, @parameters
      end

      it 'use key of ImageId that remove special characters from image.role' do
        image = @pattern.images.first
        image.role = 'web, ap, db'
        image.save!

        expected_parameters = hash_including('webapdbImageId' => image.image)
        expect_any_instance_of(Adapters::AWSAdapter).to receive(:create_stack).with(anything, anything, expected_parameters, anything)

        client = Client.new @cloud
        allow(client).to receive_message_chain(:open, :read).and_return(@template_content)
        client.create_stack @name, @pattern, @parameters
      end

      it 'will call create_stack with content of template.json' do
        expect_any_instance_of(Adapters::AWSAdapter).to receive(:create_stack)
          .with(anything, @template_content, anything, anything)

        @client.create_stack @name, @pattern, @parameters
      end
    end

    describe '#get_stack_status' do
      it 'call adapter#get_stack_status with same arguments' do
        name = 'stack_name'

        expect_any_instance_of(Adapters::AWSAdapter).to receive(:get_stack_status)
          .with(kind_of(String), kind_of(Hash))

        client = Client.new FactoryGirl.create(:cloud_aws)
        client.get_stack_status name
      end
    end

    describe '#get_outputs' do
      it 'call adapter#get_outputs with same arguments' do
        name = 'stack_name'

        expect_any_instance_of(Adapters::AWSAdapter).to receive(:get_outputs)
          .with(kind_of(String), kind_of(Hash))

        client = Client.new FactoryGirl.create(:cloud_aws)
        client.get_outputs name
      end
    end

    describe '#destroy_stack' do
      it 'call adapter#destroy_stack with same arguments' do
        name = 'stack_name'

        expect_any_instance_of(Adapters::AWSAdapter).to receive(:destroy_stack)
          .with(kind_of(String), kind_of(Hash))

        client = Client.new FactoryGirl.create(:cloud_aws)
        client.destroy_stack name
      end
    end
  end
end
