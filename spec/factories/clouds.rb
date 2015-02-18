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
  factory :cloud do
    project
    sequence(:name) { |n| "cloud_dummy_#{n}" }
    type 'dummy'
    entry_point 'entry_point'
    key '1234567890abcdef'
    secret 'fedcba9876543210'
    tenant_name 'dummy_tenant'
  end

  factory :cloud_aws, class: Cloud do
    project
    sequence(:name) { |n| "cloud_aws_#{n}" }
    type 'aws'
    entry_point 'ap-northeast-1'
    key '1234567890abcdef'
    secret 'fedcba9876543210'
    tenant_name nil
  end

  factory :cloud_openstack, class: Cloud do
    project
    sequence(:name) { |n| "cloud_openstack_#{n}" }
    type 'openstack'
    entry_point 'http://example.com/'
    key '1234567890abcdef'
    secret 'fedcba9876543210'
    tenant_name 'dummy_tenant'
  end
end
