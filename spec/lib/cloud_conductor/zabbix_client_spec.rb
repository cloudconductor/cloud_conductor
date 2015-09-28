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
    include_context 'default_resources'

    before do
      allow(CloudConductor::Config).to receive_message_chain(:zabbix, :url).and_return('http://example.com')
      allow(CloudConductor::Config).to receive_message_chain(:zabbix, :user).and_return('user')
      allow(CloudConductor::Config).to receive_message_chain(:zabbix, :password).and_return('password')

      @zabbix = double(:zabbix)
      allow(@zabbix).to receive(:login)
      allow(ZabbixAPI).to receive(:new).and_return(@zabbix)

      @client = ZabbixClient.new
    end

    describe '#initialize' do
      it 'initialize ZabbixAPI instance with configured URL' do
        expect(ZabbixAPI).to receive(:new).with('http://example.com').and_return(@zabbix)
        ZabbixClient.new
      end

      it 'login to zabbix' do
        expect(@zabbix).to receive(:login).with('user', 'password')
        ZabbixClient.new
      end
    end

    describe '#register' do
      before do
        allow(@client).to receive(:register_hostgroup).and_return(1)
        allow(@client).to receive(:register_host).and_return(2)
        allow(@client).to receive(:register_action).and_return(3)
        allow(@client).to receive(:operation).and_return('dummy command')

        @system = environment.system
      end

      it 'register hostgroup' do
        expect(@client).to receive(:register_hostgroup).with(@system.name)
        @client.register(@system)
      end

      it 'register host with hostgroup_id and monitoring host' do
        expect(@client).to receive(:register_host).with(1, 'example.com')
        @client.register(@system)
      end
    end

    describe '#register_hostgroup' do
      before do
        @hostgroup = double(:hostgroup)
        allow(@zabbix).to receive(:hostgroup).and_return(@hostgroup)
      end

      it 'add hostgroup and return id when hostgroup does not exist' do
        allow(@hostgroup).to receive(:get).and_return([])
        expect(@hostgroup).to receive(:create).with(name: 'example').and_return('groupids' => ['4'])

        expect(@client.send(:register_hostgroup, 'example')).to eq(4)
      end

      it 'return id without register when hostgroup already exists' do
        allow(@hostgroup).to receive(:get).and_return([{ 'groupid' => 5 }])
        expect(@hostgroup).not_to receive(:create)

        expect(@client.send(:register_hostgroup, 'example')).to eq(5)
      end
    end

    describe '#register_host' do
      before do
        allow(CloudConductor::Config).to receive_message_chain(:zabbix, :default_template_name).and_return('dummy template')

        @host = double(:host, create: { 'hostids' => ['7'] })
        @template = double(:template, get: [{ 'templateid' => '6' }])
        allow(@zabbix).to receive(:host).and_return(@host)
        allow(@zabbix).to receive(:template).and_return(@template)
      end

      context 'when host does not exist' do
        before do
          allow(@host).to receive(:get).and_return([])
        end

        it 'get template id from configured template name' do
          expect(@template).to receive(:get).with(filter: { name: 'dummy template' })
          expect(@client.send(:register_host, 5, 'example.com')).to eq(7)
        end

        it 'add host and return id when host does not exist' do
          expected_parameters = {
            host: 'example.com',
            interfaces: [
              {
                type: 1,
                main: 1,
                ip: '',
                dns: 'example.com',
                port: 10050,
                useip: 0
              }
            ],
            groups: [groupid: 5],
            templates: [templateid: 6]
          }
          expect(@host).to receive(:create).with(expected_parameters).and_return('hostids' => ['7'])

          expect(@client.send(:register_host, 5, 'example.com')).to eq(7)
        end
      end

      context 'when host already exists' do
        before do
          allow(@host).to receive(:get).and_return([{ 'hostid' => '7' }])
        end

        it 'return id of existing host' do
          expect(@client.send(:register_host, 5, 'example.com')).to eq(7)
        end
      end
    end

    describe '#register_action' do
      before do
        @action = double(:action)
        allow(@zabbix).to receive(:action).and_return(@action)
      end

      it 'call #insert_action when action does not exist' do
        allow(@action).to receive(:get).and_return([])
        expect(@client).to receive(:insert_action).with('dummy_name', 8, 'dummy command')

        @client.send(:register_action, 'dummy_name', 8, 'dummy command')
      end

      it 'call #update_action when action already exists' do
        allow(@action).to receive(:get).and_return([{ 'actionid' => '9' }])
        expect(@client).to receive(:update_action).with(9, 8, 'dummy command')

        @client.send(:register_action, 'dummy_name', 8, 'dummy command')
      end
    end

    describe '#insert_action' do
      before do
        @action = double(:action)
        allow(@zabbix).to receive(:action).and_return(@action)
      end

      it 'create action' do
        expected_parameters = satisfy do |params|
          expect(params[:name]).to eq('dummy_name')
          expect(params[:conditions][0][:value]).to eq(8)
          expect(params[:operations][0][:opcommand][:command]).to eq('dummy command')
        end
        expect(@action).to receive(:create).with(expected_parameters)

        @client.send(:insert_action, 'dummy_name', 8, 'dummy command')
      end
    end

    describe '#update_action' do
      before do
        @action = double(:action)
        allow(@zabbix).to receive(:action).and_return(@action)
      end

      it 'update action' do
        expected_parameters = satisfy do |params|
          expect(params[:actionid]).to eq(9)
          expect(params[:conditions][0][:value]).to eq(10)
          expect(params[:operations][0][:opcommand][:command]).to eq('update command')
        end
        expect(@action).to receive(:update).with(expected_parameters)

        @client.send(:update_action, 9, 10, 'update command')
      end
    end

    describe '#operation' do
      before do
        account = double('account', authentication_token: 'dummy_token')
        accounts = double('accounts')
        allow(accounts).to receive(:where).and_return([account])
        project = double('project', accounts: accounts, name: 'dummy')
        system = double('system', project: project)
        environment = double('environment', system: system)
        allow(Environment).to receive_message_chain(:find).and_return(environment)
      end

      it 'return curl command' do
        expected_command = %q(curl -H "Content-Type:application/json" -X POST -d '{"switch":true,"auth_token":"dummy_token"}' http://example.com/environments/1/rebuild)
        expect(@client.send(:operation, 1, 'http://example.com')).to eq(expected_command)
      end
    end
  end
end
