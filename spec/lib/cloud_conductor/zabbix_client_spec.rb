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
  describe ZabbixClient do
    describe '#register' do
      before do
        @zabbix = double('zabbix')
        ZabbixApi.stub(:connect).and_return(@zabbix)

        @zabbix.stub_chain(:hostgroups, :create_or_update)
        @zabbix.stub_chain(:templates, :get_id)
        @zabbix.stub_chain(:hosts, :create_or_update)
        @zabbix.stub_chain(:client, :api_request)

        Cloud.any_instance.stub_chain(:client, :create_stack)
        @system = FactoryGirl.create(:system)
      end

      it 'call zabbix api to register action' do
        zabbix_client = double('zabbix_client')
        zabbix_client.stub(:api_request)
        zabbix_client.should_receive(:api_request).with(hash_including(method: 'action.create'))

        @zabbix.stub(:client).and_return(zabbix_client)

        parameters = {}
        parameters[:target_host] = 'example.com'
        parameters[:system_id] = 1

        zabbix_client = ZabbixClient.new
        zabbix_client.register @system
      end
    end
  end
end
