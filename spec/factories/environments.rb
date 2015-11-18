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
  factory :environment_without_candidates, class: Environment do
    sequence(:name) { |n| "environment-#{n}" }
    description 'environment description'
    system
    blueprint_history
    platform_outputs '{}'
    ip_address '127.0.0.1'

    after(:build) do |environment, _evaluator|
      allow(environment).to receive(:create_or_update_stacks)
    end

    factory :environment, class: Environment do
      after(:build) do |environment, evaluator|
        allow(environment).to receive(:create_or_update_stacks)
        if evaluator.candidates.blank?
          environment.candidates = FactoryGirl.build_list(:candidate, 2, environment: environment)
        end
      end
    end
  end
end
