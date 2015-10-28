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
    environment { create(:environment) }
    pattern { create(:pattern_snapshot, type: :platform) }
    cloud { create(:cloud, :aws) }

    sequence(:name) { |n| "stack-#{n}" }
    template_parameters '{}'
    parameters '{ "dummy": "value" }'

    before(:create) do
      Stack.skip_callback :save, :before, :create_stack
      Stack.skip_callback :save, :before, :update_stack
    end

    after(:create) do
      Stack.set_callback :save, :before, :create_stack, if: -> { ready_for_create? }
      Stack.set_callback :save, :before, :update_stack, if: -> { ready_for_update? }
    end
  end
end
