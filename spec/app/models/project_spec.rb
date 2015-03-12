describe Project do
  before do
    @project = Project.new
    @project.name = 'test'
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @project.save! }.to change { Project.count }.by(1)
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
end
