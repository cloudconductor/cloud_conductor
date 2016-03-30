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
  factory :stack, class: Stack do
    environment { build(:environment) }
    pattern_snapshot { build(:pattern_snapshot, type: :platform, blueprint_history: environment.blueprint_history, images: FactoryGirl.build_list(:image, 1, status: :CREATE_COMPLETE)) }
    cloud { build(:cloud, :aws, project: environment.system.project) }

    sequence(:name) { |n| "stack-#{n}" }

    after(:build) do |stack, _evaluator|
      allow(stack).to receive(:create_stack)
      allow(stack).to receive(:update_stack)
    end
  end
end
