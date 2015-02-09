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
  describe '.primary' do
    it 'return single candidate that has highest priority on specified environment' do
      environment = FactoryGirl.create(:environment)
      environment.add_cloud FactoryGirl.create(:cloud_aws), 10
      environment.add_cloud FactoryGirl.create(:cloud_aws), 30
      environment.add_cloud FactoryGirl.create(:cloud_aws), 20
      environment.save!

      expect(environment.candidates.primary).to eq(environment.candidates[1])
    end

    it 'ignore candidates on other environment' do
      environment1 = FactoryGirl.create(:environment)
      environment1.add_cloud FactoryGirl.create(:cloud_aws), 30
      environment1.save!

      environment2 = FactoryGirl.create(:environment)
      environment2.add_cloud FactoryGirl.create(:cloud_aws), 10
      environment2.add_cloud FactoryGirl.create(:cloud_aws), 20
      environment2.save!

      expect(environment2.candidates.primary).to eq(environment2.candidates[1])
    end
  end
end
