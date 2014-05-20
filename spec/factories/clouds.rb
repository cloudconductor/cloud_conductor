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
  factory :cloud_aws, class: Cloud do
    name 'cloud-aws-12345678'
    cloud_type 'aws'
    cloud_entry_point_url 'http://example.com/'
    key '1234567890abcdef'
    secret 'fedcba9876543210'
    tenant_id nil
  end

  factory :cloud_openstack, class: Cloud do
    name 'cloud-openstack-12345678'
    cloud_type 'openstack'
    cloud_entry_point_url 'http://example.com/'
    key '1234567890abcdef'
    secret 'fedcba9876543210'
    tenant_id '1'
  end
end
