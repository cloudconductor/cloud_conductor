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
    sequence(:name) { |n| "cloud_#{n}" }
    description 'cloud description'
    type 'aws'
    entry_point 'ap-northeast-1'
    key 'aws_access_key'
    secret 'aws_secret_key'
    tenant_name nil

    trait :aws do
      # default
    end

    trait :openstack do
      type 'openstack'
      entry_point 'http://127.0.0.1:5000/v1'
      key 'openstack username'
      secret 'openstack password'
      tenant_name 'openstack tenant name'
    end
  end
end
