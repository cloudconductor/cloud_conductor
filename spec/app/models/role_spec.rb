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
describe Role do
  include_context 'default_resources'

  before do
    @role = Role.new
    @role.name = 'test'
    @role.project = project
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @role.save! }.to change { Role.count }.by(1)
    end

    it 'create with long test' do
      @role.description = '*' * 255
      @role.save!
    end
  end

  describe '#destroy' do
    it 'delete role record' do
      @role.save!
      expect { @role.destroy }.to change { Role.count }.by(-1)
    end

    it 'delete all assignment_role records' do
      @role.assignments << FactoryGirl.create(:assignment, project: project, account: FactoryGirl.create(:account))
      @role.assignments << FactoryGirl.create(:assignment, project: project, account: FactoryGirl.create(:account))
      @role.save!
      expect(@role.assignment_roles.size).to eq(2)
      expect { @role.destroy }.to change { AssignmentRole.count }.by(-2)
    end

    it 'delete all permission records' do
      @role.permissions.delete_all
      @role.permissions << FactoryGirl.create(:permission, :read_only, role: @role, model: 'project')
      @role.permissions << FactoryGirl.create(:permission, :manage, role: @role, model: 'system')

      expect(@role.permissions.size).to eq(2)
      expect { @role.destroy }.to change { Permission.count }.by(-2)
    end

    it 'raise error and cancel destroy when specified role is used in some accounts' do
      allow(@role).to receive(:used?).and_return(true)

      expect do
        expect { @role.destroy }.to(raise_error('Can\'t destroy role that is used in some account assignments.'))
      end.not_to change { Role.count }
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@role.valid?).to be_truthy
    end

    it 'returns false when project is unset' do
      @role.project = nil
      expect(@role.valid?).to be_falsey
    end

    it 'returns false when name is unset' do
      @role.name = nil
      expect(@role.valid?).to be_falsey
    end

    it 'returns false when name is not unique in two Roles on one Project' do
      FactoryGirl.create(:role, name: 'test', project: project)
      expect(@role.valid?).to be_falsey
    end

    it 'returns true when name is not unique in two Roles on different Projects' do
      FactoryGirl.create(:role, name: 'test', project: Project.new(name: 'sample'))
      expect(@role.valid?).to be_truthy
    end
  end

  describe '#used?' do
    it 'return true when role is used by some accounts' do
      expect(@role).to receive_message_chain(:assignments, :count).and_return(1)
      expect(@role.used?).to eq(true)
    end

    it 'return false when role is unused by all accounts' do
      expect(@role).to receive_message_chain(:assignments, :count).and_return(0)
      expect(@role.used?).to eq(false)
    end
  end

  describe 'scope' do
    it ':find_by_project_id' do
      expect(::Role.find_by_project_id(@role.project.id)).to eq(::Project.find(@role.project.id).roles.all)
    end

    it ':assigned_to' do
      account = project.assignments.first.account
      roles = ::Role.joins(:assignments).where(::Role.arel_table[:project_id].eq(project.id).and(::Assignment.arel_table[:account_id].eq(account.id)))

      expect(::Role.assigned_to(project.id, account.id)).to eq(roles)
    end
  end
end
