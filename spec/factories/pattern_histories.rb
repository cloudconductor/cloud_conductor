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
  factory :pattern_history do
    blueprint_history
    association :pattern, :platform
    sequence(:name) { |n| "pattern_history-#{n}" }
    url 'https://example.com/cloudconductor-dev/sample_platform_pattern.git'

    before(:create) do
      PatternHistory.skip_callback :create, :before, :freeze_pattern
      PatternHistory.skip_callback :create, :before, :create_images
    end

    after(:create) do
      PatternHistory.set_callback :create, :before, :create_images
      PatternHistory.set_callback :create, :before, :freeze_pattern
    end
  end
end
