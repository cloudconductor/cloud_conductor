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
    before do
      CloudConductor::Config.stub_chain(:zabbix, :configuration)
      CloudConductor::Config.stub_chain(:cloudconductor, :url).and_return('http://example.com/zabbix')

      @zabbix_client = double('zabbix')

      @zabbix = double('zabbix')
      @zabbix.stub(:client).and_return(@zabbix_client)

      ZabbixApi.stub(:connect).and_return(@zabbix)

      @client = ZabbixClient.new

      @system = FactoryGirl.create(:system, name: 'example', monitoring_host: 'example.com')
    end

    describe '#initialize' do
      it 'return instance of ZabbixClient without error' do
        expect(ZabbixClient.new).to be_is_a ZabbixClient
      end
    end

    describe '#register' do
      before do
        CloudConductor::Config.stub_chain(:zabbix, :template_host).and_return('Dummy Template Host')
        @zabbix.stub_chain(:hostgroups, :create_or_update).and_return(1)
        @zabbix.stub_chain(:templates, :get_id).and_return(2)
        @client.stub(:get_action)
        @client.stub(:add_host).and_return(3)
        @client.stub(:add_action)
        @client.stub(:update_action)
      end

      it 'call Hostgroups#create_or_update with name of system' do
        hostgroups = double('ZabbixApi::Hostgroups')
        @zabbix.stub(:hostgroups).and_return(hostgroups)

        hostgroups.should_receive(:create_or_update).with(name: 'example')
        @client.register(@system)
      end

      it 'call Hostgroups#create_or_update without uuid' do
        hostgroups = double('ZabbixApi::Hostgroups')
        @zabbix.stub(:hostgroups).and_return(hostgroups)

        @system.name = 'example-8d6cbaf0-ee69-4a7c-b1da-6d14ea241dce'
        hostgroups.should_receive(:create_or_update).with(name: 'example')
        @client.register(@system)
      end

      it 'call Templates#get_id with fixed name of template' do
        templates = double('ZabbixApi::Templates')
        @zabbix.stub(:templates).and_return(templates)

        templates.should_receive(:get_id).with(host: 'Dummy Template Host')
        @client.register(@system)
      end

      it 'call get_action with action_name' do
        @client.should_receive(:get_action).with(action_name: 'FailOver_example')
        @client.register(@system)
      end

      it 'call add_host when target action does not exist' do
        @client.stub(:get_action).and_return(nil)
        @client.should_receive(:add_host).with('example.com', 1, 2)
        @client.register(@system)
      end

      it 'call add_action  when target action does not exist' do
        @client.stub(:get_action).and_return(nil)

        expected_parameters = {
          host_id: 3,
          system_id: @system.id,
          action_name: 'FailOver_example'
        }
        @client.should_receive(:add_action).with(expected_parameters)
        @client.register(@system)
      end

      it 'does not call update_action when target action does not exist' do
        @client.stub(:get_action).and_return(nil)
        @client.should_not_receive(:update_action)
        @client.register(@system)
      end

      it 'call update_action when target action already exist' do
        @client.stub(:get_action).and_return('4')
        expected_parameters = {
          system_id: @system.id,
          action_name: 'FailOver_example',
          action_id: '4'
        }
        @client.should_receive(:update_action).with(expected_parameters)
        @client.register(@system)
      end

      it 'does not call add_host and add_action when target action already exist' do
        @client.stub(:get_action).and_return('4')
        @client.should_not_receive(:add_host)
        @client.should_not_receive(:add_action)
      end
    end

    describe '#get_hostgroups with parameters' do
      it 'request zabbix api with host.get method' do
        expected_parameters = {
          method: 'host.get',
          params: hash_including(
            filter: hash_including(
              hostid: [1]
            )
          )
        }

        response = [
          {
            hostid: 1,
            groups: {
              key: 'dummy'
            }
          }
        ]

        @zabbix_client.should_receive(:api_request).with(hash_including(expected_parameters)).and_return response
        result = @client.send(:get_hostgroups, 1)

        expect(result).to eq(key: 'dummy')
      end
    end

    describe '#update_host' do
      it 'request zabbix api with host.update method' do
        expected_parameters = {
          method: 'host.update',
          params: {
            hostid: 1,
            groups: [
              { groupid: 2 }
            ]
          }
        }

        @client.stub(:get_hostgroups).and_return []

        @zabbix_client.should_receive(:api_request).with(expected_parameters)
        @client.send(:update_host, 1, 2)
      end
    end

    describe '#get_host_id' do
      it 'get hosts via ZabbixApi with target hostname' do
        hosts = double('ZabbixApi::Hosts')
        @zabbix.stub(:hosts).and_return(hosts)

        hosts.should_receive(:get).with(name: 'example.com').and_return([])

        @client.send(:get_host_id, 'example.com')
      end
    end

    describe '#add_host' do
      it 'call update_host only when host already exist' do
        @client.stub(:get_host_id).and_return 1
        @client.should_receive(:update_host).with(1, 2)
        @zabbix.should_not_receive(:hosts)

        @client.send(:add_host, 'example.com', 2, 3)
      end

      it 'call Hosts#create_or_update with parameters wieh host does not exist' do
        @client.stub(:get_host_id).and_return nil

        hosts = double('ZabbixApi::Hosts')
        @zabbix.stub(:hosts).and_return(hosts)

        expected_parameters = {
          host: 'example.com',
          interfaces: [
            hash_including(
              dns: 'example.com'
            )
          ],
          groups: [groupid: 1],
          templates: [templateid: 2]
        }

        hosts.should_receive(:create_or_update).with(expected_parameters)
        @client.send(:add_host, 'example.com', 1, 2)
      end
    end

    describe '#recreate_system_command' do
      it 'return curl command with arguments' do
        command = @client.send(:recreate_system_command, 1)
        expect(command).to eq('curl -H "Content-Type:application/json" -X POST -d \'{"system_id": "1"}\' http://example.com/zabbix')
      end
    end

    describe '#add_action' do
      it 'request zabbix api with action.create method' do
        @client.stub(:recreate_system_command).and_return('dummy_command')

        expected_parameters = satisfy do |params|
          expect(params[:method]).to eq('action.create')
          expect(params[:params][:name]).to eq('dummy_name')
          expect(params[:params][:conditions][0][:value]).to eq(1)
          expect(params[:params][:operations][0][:opcommand][:command]).to eq('dummy_command')
        end

        @zabbix_client.should_receive(:api_request).with(expected_parameters)
        @client.send(
          :add_action,
          host_id: 1,
          system_id: 2,
          action_name: 'dummy_name'
        )
      end
    end

    describe '#get_action' do
      it 'request zabbix api with action.get method' do
        expected_parameters = {
          method: 'action.get',
          params: {
            filter: {
              name: 'dummy_name'
            }
          }
        }

        @zabbix_client.should_receive(:api_request).with(hash_including(expected_parameters)).and_return [{ 'actionid' => '1' }]
        @client.send(:get_action, action_name: 'dummy_name')
      end
    end

    describe '#update_action' do
      it 'request zabbix api with action.update method' do
        @client.stub(:recreate_system_command).and_return('dummy_command')

        expected_parameters = satisfy do|params|
          expect(params[:method]).to eq('action.update')
          expect(params[:params][:name]).to eq('dummy_name')
          expect(params[:params][:actionid]).to eq('2')
          expect(params[:params][:operations][0][:opcommand][:command]).to eq('dummy_command')
        end

        @zabbix_client.should_receive(:api_request).with(expected_parameters)
        @client.send(
          :update_action,
          system_id: 1,
          action_name: 'dummy_name',
          action_id: '2'
        )
      end
    end
  end
end
