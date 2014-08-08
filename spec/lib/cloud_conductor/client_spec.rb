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
      it 'call adapter#create_stack with same arguments' do
        name = 'stack_name'
        template = '{}'
        parameters = {}
        options = {}

        Adapters::AWSAdapter.any_instance.should_receive(:create_stack)
          .with(kind_of(String), kind_of(String), kind_of(Hash), kind_of(Hash))

        client = Client.new FactoryGirl.create(:cloud_aws)
        client.create_stack name, template, parameters, options
      end
    end

    describe '#get_stack_status' do
      it 'call adapter#get_stack_status with same arguments' do
        name = 'stack_name'
        options = {}

        Adapters::AWSAdapter.any_instance.should_receive(:get_stack_status)
          .with(kind_of(String), kind_of(Hash))

        client = Client.new FactoryGirl.create(:cloud_aws)
        client.get_stack_status name, options
      end
    end

    describe '#get_outputs' do
      it 'call adapter#get_outputs with same arguments' do
        name = 'stack_name'
        options = {}

        Adapters::AWSAdapter.any_instance.should_receive(:get_outputs)
          .with(kind_of(String), kind_of(Hash))

        client = Client.new FactoryGirl.create(:cloud_aws)
        client.get_outputs name, options
      end
    end

    describe '#destroy_stack' do
      it 'call adapter#destroy_stack with same arguments' do
        name = 'stack_name'
        options = {}

        Adapters::AWSAdapter.any_instance.should_receive(:destroy_stack)
          .with(kind_of(String), kind_of(Hash))

        client = Client.new FactoryGirl.create(:cloud_aws)
        client.destroy_stack name, options
      end
    end
  end
end
