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
  factory :pattern_snapshot do
    blueprint_history { build(:blueprint_history) }
    sequence(:name) { |n| "pattern_snapshot-#{n}" }
    url 'https://example.com/cloudconductor-dev/sample_platform_pattern.git'

    after(:build) do |pattern_snapshot, _evaluator|
      allow(pattern_snapshot).to receive(:freeze_pattern)
      allow(pattern_snapshot).to receive(:create_images)
    end
  end
end
