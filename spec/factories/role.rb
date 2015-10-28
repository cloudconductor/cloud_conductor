# -*- coding: utf-8 -*-
# Copyright 2015 TIS Inc.
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
#
FactoryGirl.define do
  factory :role do
    project
    sequence(:name) { |n| "role_#{n}" }
    description 'Role Description'

    after(:create) do |role|
      models = [:cloud, :base_image, :pattern, :blueprint, :system, :environment, :application, :application_history, :deployment]
      models.each do |model|
        role.add_permission(model, :manage)
      end
      if role.name == 'administrator'
        role.add_permission(:project, :manage)
        role.add_permission(:assignment, :manage)
        role.add_permission(:account, :read, :create)
        role.add_permission(:role, :manage)
      else
        role.add_permission(:project, :read)
        role.add_permission(:assignment, :read)
        role.add_permission(:account, :read)
        role.add_permission(:role, :read)
      end
    end
  end
end
