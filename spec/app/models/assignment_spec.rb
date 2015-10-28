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

describe Assignment do
  include_context 'default_resources'

  before do
    @assignment = Assignment.new
    @assignment.project = project
    @assignment.account = FactoryGirl.create(:account)
    role = FactoryGirl.create(:role, project: project)
    @assignment.roles = [role]
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @assignment.save! }.to change { Assignment.count }.by(1)
    end
  end

  describe '#destroy' do
    it 'delete assignment record' do
      @assignment.save!
      expect { @assignment.destroy }.to change { Assignment.count }.by(-1)
    end

    it 'delete all assignment_role records' do
      @assignment.roles << FactoryGirl.create(:role, project: project)
      @assignment.save!

      expect(@assignment.assignment_roles.size).to eq(2)
      expect { @assignment.destroy }.to change { AssignmentRole.count }.by(-2)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@assignment.valid?).to be_truthy
    end

    it 'returns false when project is unset' do
      @assignment.project = nil
      expect(@assignment.valid?).to be_falsey
    end

    it 'returns false when account is unset' do
      @assignment.account = nil
      expect(@assignment.valid?).to be_falsey
    end
  end

  describe '#administrator?' do
    it 'returns true' do
      @assignment.roles << project.roles.find_by(name: 'administrator')
      @assignment.save!
      expect(@assignment.administrator?).to be_truthy
    end

    it 'returns false' do
      expect(@assignment.administrator?).to be_falsey
    end
  end
end
