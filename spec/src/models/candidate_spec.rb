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
    it 'return single candidates that has highest priority on specified system' do
      system = FactoryGirl.build(:system)
      system.add_cloud FactoryGirl.create(:cloud_aws), 10
      system.add_cloud FactoryGirl.create(:cloud_aws), 30
      system.add_cloud FactoryGirl.create(:cloud_aws), 20
      system.save!

      expect(system.candidates.primary).to eq(system.candidates[1])
    end

    it 'ignore candidates on other system' do
      system1 = FactoryGirl.build(:system)
      system1.add_cloud FactoryGirl.create(:cloud_aws), 30
      system1.save!

      system2 = FactoryGirl.build(:system)
      system2.add_cloud FactoryGirl.create(:cloud_aws), 10
      system2.add_cloud FactoryGirl.create(:cloud_aws), 20
      system2.save!

      expect(system2.candidates.primary).to eq(system2.candidates[1])
    end
  end
end
