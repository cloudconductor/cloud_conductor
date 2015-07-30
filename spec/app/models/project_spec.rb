describe Project do
  before do
    @project = Project.new
    @project.name = 'test'
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @project.save! }.to change { Project.count }.by(1)
    end

    it 'create with long text' do
      @project.description = '*' * 256
      @project.save!
    end
  end

  describe '#destroy' do
    it 'delete project record' do
      @project.save!
      expect { @project.destroy }.to change { Project.count }.by(-1)
    end

    it 'delete all assignment records' do
      account1 = FactoryGirl.create(:account)
      account2 = FactoryGirl.create(:account)
      FactoryGirl.create(:assignment, project: @project, account: account1)
      FactoryGirl.create(:assignment, project: @project, account: account2)

      expect(@project.assignments.size).to eq(3)
      expect { @project.destroy }.to change { Assignment.count }.by(-3)
    end

    it 'delete all cloud records' do
      FactoryGirl.create(:cloud, :aws, project: @project)
      FactoryGirl.create(:cloud, :aws, project: @project)

      expect(@project.clouds.size).to eq(2)
      expect { @project.destroy }.to change { Cloud.count }.by(-2)
    end

    it 'delete all system records' do
      FactoryGirl.create(:system, project: @project)
      FactoryGirl.create(:system, project: @project)

      expect(@project.systems.size).to eq(2)
      expect { @project.destroy }.to change { System.count }.by(-2)
    end

    it 'delete all blueprint records' do
      FactoryGirl.create(:blueprint, project: @project)
      FactoryGirl.create(:blueprint, project: @project)

      expect(@project.blueprints.size).to eq(2)
      expect { @project.destroy }.to change { Blueprint.count }.by(-2)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@project.valid?).to be_truthy
    end

    it 'returns false when name is unset' do
      @project.name = nil
      expect(@project.valid?).to be_falsey

      @project.name = ''
      expect(@project.valid?).to be_falsey
    end
  end

  describe '#assign_project_administrator' do
    it 'build assignment if current_account is not nil' do
      @project.current_account = FactoryGirl.create(:account)
      expect { @project.assign_project_administrator }.to change { @project.assignments.size }.by(1)
    end

    it 'not build assignment if current_account is nil' do
      expect { @project.assign_project_administrator }.not_to change { @project.assignments.size }
    end
  end

  describe '#create_monitoring_account' do
    it 'create monitoring account' do
      expect { @project.create_monitoring_account }.to change { Account.count }.by(1)
    end

    it 'create assignment for monitoring' do
      expect(@project.assignments).to be_empty
      @project.create_monitoring_account
      expect(@project.assignments).not_to be_empty
      expect(@project.assignments.first.account).to eq(Account.last)
      expect(@project.assignments.first.role).to eq('operator')
    end
  end

  describe '#delete_monitoring_account' do
    it 'delete monitoring account' do
      @project.create_monitoring_account
      expect { @project.delete_monitoring_account }.to change { Account.count }.by(-1)
    end
  end

  describe '#assign_project_member' do
    before do
      @account = FactoryGirl.create(:account)
    end

    context 'when assignments exists account' do
      it 'change role on assignment that between project and account' do
        @project.current_account = @account
        @project.save!

        # Need to reload for avoid to ActiveRecord bug
        project = Project.find(@project)

        expect { project.assign_project_member(@account) }.to change { @project.assignments.find_by(account: @account).role }.from('administrator').to('operator')
      end
    end

    context 'when assignments not exists account' do
      it 'create assignment that has specified role' do
        @project.save!

        # Need to reload for avoid to ActiveRecord bug
        project = Project.find(@project)

        expect { project.assign_project_member(@account, :administrator) }.to change { Assignment.count }.by(1)
        expect(project.assignments.find_by(account: @account).role).to eq('administrator')
      end
    end
  end
end
