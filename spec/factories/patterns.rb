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
  factory :pattern do
    project
    protocol 'git'
    revision 'master'

    trait :platform do
      sequence(:name) { |n| "platform_pattern-#{n}" }
      url 'https://example.com/cloudconductor-dev/sample_platform_pattern.git'
      type 'platform'
    end

    trait :optional do
      sequence(:name) { |n| "optional_pattern-#{n}" }
      url 'https://example.com/cloudconductor-dev/sample_optional_pattern.git'
      type 'optional'
    end

    before(:create) do
      Pattern.skip_callback :save, :before, :update_metadata
    end

    after(:create) do
      Pattern.set_callback :save, :before, :update_metadata
    end
  end
end
