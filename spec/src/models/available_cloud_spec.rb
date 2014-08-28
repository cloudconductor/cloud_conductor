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
describe AvailableCloud do
  before do
    @cloud_aws = FactoryGirl.create(:cloud_aws)
    @cloud_openstack = FactoryGirl.create(:cloud_openstack)

    @pattern = FactoryGirl.create(:pattern)

    @system = System.new
    @system.name = 'Test'
    @system.pattern = @pattern
    @system.template_parameters = '{}'
    @system.parameters = '{}'
    @system.monitoring_host = nil
    @system.domain = 'example.com'

    @system.add_cloud(@cloud_aws, 1)
    @system.add_cloud(@cloud_openstack, 2)

    @client = double('client')
    Cloud.any_instance.stub(:client).and_return(@client)

    CloudConductor::DNSClient.stub_chain(:new, :update)
    CloudConductor::ZabbixClient.stub_chain(:new, :register)
  end

  describe '.active' do
    it 'return cloud that has active flag' do
      @client.stub(:create_stack).and_return(nil)

      @system.save!

      expect(@system.available_clouds.active).to eq(@cloud_openstack)
    end

    it 'return nil if all clouds are disabled' do
      @client.stub(:create_stack).and_raise

      @system.save!

      expect(@system.available_clouds.active).to be_nil
    end
  end
end
