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
        client = Client.new :aws
        expect(client.type).to eq(:aws)
        expect(client.adapter.class).to eq(Adapters::AWSAdapter)
      end

      it 'returns initialized client with openstack adapter' do
        client = Client.new :openstack
        expect(client.type).to eq(:openstack)
        expect(client.adapter.class).to eq(Adapters::OpenStackAdapter)
      end
    end

    describe '#create_stack' do
      it 'call adapter#create_stack with same arguments' do
        name = 'stack_name'
        template = '{}'
        parameters = '{}'
        options = {}

        Adapters::AWSAdapter.any_instance.should_receive(:create_stack)
          .with(kind_of(String), kind_of(String), kind_of(String), kind_of(Hash))

        client = Client.new :aws
        client.create_stack name, template, parameters, options
      end
    end

    describe '#get_stack_status' do
      it 'call adapter#get_stack_status with same arguments' do
        name = 'stack_name'
        options = {}

        Adapters::AWSAdapter.any_instance.should_receive(:get_stack_status)
          .with(kind_of(String), kind_of(Hash))

        client = Client.new :aws
        client.get_stack_status name, options
      end
    end

    describe '#enable_monitoring' do
      before do
        @zabbix = double('zabbix')
        ZabbixApi.stub(:connect).and_return(@zabbix)

        @zabbix.stub_chain(:hostgroups, :create_or_update)
        @zabbix.stub_chain(:templates, :get_id)
        @zabbix.stub_chain(:hosts, :create_or_update)
        @zabbix.stub_chain(:client, :api_request)
      end

      it 'call zabbix api to register action' do
        zabbix_client = double('zabbix_client')
        zabbix_client.stub(:api_request)
        zabbix_client.should_receive(:api_request).with(hash_including(method: 'action.create'))

        @zabbix.stub(:client).and_return(zabbix_client)

        parameters = {}
        parameters[:target_host] = 'example.com'
        parameters[:system_id] = 1

        client = Client.new :dummy
        client.enable_monitoring 'name', parameters
      end
    end
  end
end
