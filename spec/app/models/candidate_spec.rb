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
describe Candidate do
  include_context 'default_resources'

  let(:cloud1) { FactoryGirl.create(:cloud, :aws) }
  let(:cloud2) { FactoryGirl.create(:cloud, :openstack) }
  let(:cloud3) { FactoryGirl.create(:cloud, :aws, name: 'new_cloud') }

  describe '.primary' do
    it 'return single candidate that has highest priority on specified environment' do
      environment = FactoryGirl.build(:environment, system: system, blueprint_history: blueprint_history)
      environment.candidates.delete_all
      environment.candidates << FactoryGirl.build(:candidate, environment: environment, cloud: cloud1, priority: 10)
      environment.candidates << FactoryGirl.build(:candidate, environment: environment, cloud: cloud2, priority: 30)
      environment.candidates << FactoryGirl.build(:candidate, environment: environment, cloud: cloud3, priority: 20)
      environment.save!

      expect(environment.candidates.primary).to eq(environment.candidates[1])
    end

    it 'ignore candidates on other environment' do
      environment1 = FactoryGirl.build(:environment, system: system, blueprint_history: blueprint_history)
      environment1.candidates.delete_all
      environment1.candidates << FactoryGirl.build(:candidate, environment: environment1, cloud: cloud1, priority: 30)
      environment1.save!

      environment2 = FactoryGirl.build(:environment, system: system, blueprint_history: blueprint_history)
      environment2.candidates.delete_all
      environment2.candidates << FactoryGirl.build(:candidate, environment: environment2, cloud: cloud2, priority: 10)
      environment2.candidates << FactoryGirl.build(:candidate, environment: environment2, cloud: cloud3, priority: 20)
      environment2.save!

      expect(environment2.candidates.primary).to eq(environment2.candidates[1])
    end
  end
end
