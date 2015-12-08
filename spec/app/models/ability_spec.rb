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

describe Ability do
  include_context 'default_resources'

  before do
    account = FactoryGirl.create(:account)
    @project = FactoryGirl.create(:project, owner: account)
  end

  describe '#can?' do
    it 'returns true' do
      project = ::Project.find(@project)
      role = project.roles.find_by(name: 'administrator')
      expect(role).to_not be_nil

      expect(project.accounts.size).to eq(2)

      expect(role.permissions.size).to_not eq(0)

      account = role.assignments.first.account

      ability = Ability.new(account, project)

      expect(ability.can?(:read, project)).to be_truthy
      expect(ability.can?(:create, ::Project)).to be_truthy
      expect(ability.can?(:update, project)).to be_truthy
      expect(ability.can?(:destroy, project)).to be_truthy
    end

    it 'returns false' do
      project = ::Project.find(@project)
      role = project.roles.find_by(name: 'operator')
      expect(role).to_not be_nil

      expect(project.accounts.size).to eq(2)
      expect(role.permissions.size).to_not eq(0)

      account = role.assignments.first.account
      ability = Ability.new(account, project)

      expect(ability.can?(:read, project)).to be_truthy
      expect(ability.can?(:create, ::Project)).to be_truthy
      expect(ability.can?(:update, project)).to be_falsey
      expect(ability.can?(:destroy, project)).to be_falsey
    end
  end
end
