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
FactoryGirl.define do
  factory :environment, class: Environment do
    sequence(:name) { |n| "system-#{n}" }
    domain 'example.com'
    template_parameters '{ "dummy": "value" }'
    system
    blueprint

    before(:create) do |environment|
      Environment.skip_callback :save, :before, :enable_monitoring
      Environment.skip_callback :save, :before, :update_dns

      environment.add_cloud create(:cloud_aws), 1
      environment.add_cloud create(:cloud_openstack), 2

      environment.stacks << create(:stack, environment: environment)
      environment.stacks << create(:stack, environment: environment)
    end

    after(:create) do
      Environment.set_callback :save, :before, :enable_monitoring, if: -> { monitoring_host && monitoring_host_changed? }
      Environment.set_callback :save, :before, :update_dns, if: -> { ip_address }
    end
  end
end
