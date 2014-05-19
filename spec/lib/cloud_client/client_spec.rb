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
module CloudClient
  describe Client do
    describe '#new' do
      it 'returns initialized client with aws adapter' do
        client = Client.new :aws
        expect(client.type).to eq(:aws)
        expect(client.adapter.class).to eq(Adapters::AWS)
      end

      it 'returns initialized client with openstack adapter' do
        client = Client.new :openstack
        expect(client.type).to eq(:openstack)
        expect(client.adapter.class).to eq(Adapters::OpenStack)
      end
    end

    describe '#create_stack' do
      it 'call adapter#create_stack with same arguments' do
        template = '{}'
        parameters = '{}'
        options = {}

        # expect_any_instance_of(Adapters::AWS).to receive(:create_stack)
        Adapters::AWS.any_instance.should_receive(:create_stack).with(kind_of(String), kind_of(String), kind_of(Hash))

        client = Client.new :aws
        client.create_stack template, parameters, options
      end
    end
  end
end
