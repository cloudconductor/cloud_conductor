describe Project do
  before do
    @project = FactoryGirl.build(:project)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @project.save! }.to change { Project.count }.by(1)
    end

    it 'create with long text' do
      @project.description = '*' * 256
      @project.save!
    end

    it 'call #assign_project_administrator callback' do
      expect(@project).to receive(:assign_project_administrator)
      @project.save!
    end

    it 'call #create_monitoring_account callback' do
      expect(@project).to receive(:create_monitoring_account)
      @project.save!
    end
  end

  describe '#destroy' do
    it 'delete project record' do
      @project.save!
      expect { @project.destroy }.to change { Project.count }.by(-1)
    end

    it 'delete all assignment records' do
      @project.save!
      expect(@project.assignments.size).to eq(1)
      expect { @project.destroy }.to change { Assignment.count }.by(-1)
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
      allow_any_instance_of(Pattern).to receive(:set_metadata_from_repository)
      FactoryGirl.create(:blueprint, project: @project)
      FactoryGirl.create(:blueprint, project: @project)

      expect(@project.blueprints.size).to eq(2)
      expect { @project.destroy }.to change { Blueprint.count }.by(-2)
    end

    it 'call #delete_monitoring_account callback' do
      expect(@project).to receive(:delete_monitoring_account)
      @project.save!
      @project.destroy
    end

    it 'delete all role records' do
      FactoryGirl.create(:role, project: @project)
      FactoryGirl.create(:role, project: @project)

      expect(@project.roles.size).to eq(4)
      expect { @project.destroy }.to change { Role.count }.by(-4)
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
      expect(@project.assignments.first.roles.first.name).to eq('operator')
    end
  end

  describe '#delete_monitoring_account' do
    before do
      allow(@project).to receive(:create_monitoring_account).and_call_original
      allow(@project).to receive(:delete_monitoring_account).and_call_original
    end

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

        expect { project.assign_project_member(@account) }.to change { @project.assignments.find_by(account: @account).roles.first.name }.from('administrator').to('operator')
      end
    end

    context 'when assignments not exists account' do
      it 'create assignment that has specified role' do
        @project.save!

        # Need to reload for avoid to ActiveRecord bug
        project = Project.find(@project)

        expect { project.assign_project_member(@account, :administrator) }.to change { Assignment.count }.by(1)
        expect(project.assignments.find_by(account: @account).roles.first.name).to eq('administrator')
      end
    end
  end

  describe '#base_images' do
    it 'collect base images belongs to this project' do
      cloud = FactoryGirl.create(:cloud, :aws, project: @project)
      FactoryGirl.create(:base_image, cloud: cloud, os_version: 'CentOS-6.5')

      results = @project.base_images('CentOS-6.5')
      expect(results.size).to eq(1)
      expect(results.first.os_version).to eq('CentOS-6.5')
    end
  end

  describe 'create_preset_roles' do
    it 'create roles' do
      @project.save!

      expect(Role.where(project: @project).count).to eq(2)
      expect(Role.find_by(project: @project, name: 'administrator')).to_not be_nil
      expect(Role.find_by(project: @project, name: 'operator')).to_not be_nil
    end
  end
end
