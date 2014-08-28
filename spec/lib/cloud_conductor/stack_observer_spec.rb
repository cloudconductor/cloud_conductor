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
  describe StackObserver do
    before do
      @cloud_aws = FactoryGirl.create(:cloud_aws)
      @cloud_openstack = FactoryGirl.create(:cloud_openstack)

      @pattern = FactoryGirl.create(:pattern)

      @system = System.new
      @system.name = 'Test'
      @system.pattern = @pattern
      @system.template_parameters = '{}'
      @system.parameters = '{ "dummy": "value" }'
      @system.monitoring_host = nil
      @system.domain = 'example.com'

      @system.add_cloud(@cloud_aws, 1)
      @system.add_cloud(@cloud_openstack, 2)

      CloudConductor::Client.stub_chain(:new, :create_stack)
      @system.save!

      System.any_instance.stub(:status)
      System.any_instance.stub(:outputs)

      @serf_client = double(:serf_client, call: nil)
      @system.stub(:serf).and_return(@serf_client)
    end

    describe '#update' do
      before do
        @observer = StackObserver.new
      end

      it 'check all stacks without exception' do
        @observer.update
      end

      it 'will request to serf with payload when block yield' do
        System.skip_callback :save, :before, :enable_monitoring
        expected_payload = {}
        expected_payload[:parameters] = { 'dummy' => 'value' }
        @serf_client.should_receive(:call).with('event', 'configure', expected_payload)

        @observer.stub(:update_systems).and_yield(@system, '127.0.0.1')
        @observer.update
        System.set_callback :save, :before, :enable_monitoring, if: -> { monitoring_host_changed? }
      end
    end
  end
end
