module ModelSpecHelper
  shared_context 'default_resources' do
    let(:project) { FactoryGirl.create(:project) }
    let(:cloud) { FactoryGirl.create(:cloud, project: project) }
    let(:base_image) { cloud.base_images.first || FactoryGirl.create(:base_image, cloud: cloud) }
    let(:blueprint) { FactoryGirl.create(:blueprint, project: project) }
    let(:pattern) { FactoryGirl.create(:pattern, :platform, project: project) }
    let(:blueprint_history) { FactoryGirl.create(:blueprint_history, blueprint: blueprint) }
    let(:pattern_snapshot) do
      @cloud = Cloud.eager_load(:project).find(cloud)
      FactoryGirl.create(:pattern_snapshot, blueprint_history: blueprint_history, images: FactoryGirl.build_list(:image, 1, cloud: @cloud, status: :CREATE_COMPLETE))
    end
    let(:blueprint_pattern) do
      blueprint.blueprint_patterns << FactoryGirl.create(:blueprint_pattern, blueprint: blueprint, pattern: pattern)
      blueprint.blueprint_patterns.first
    end
    let(:image) { pattern_snapshot.images.first }
    let(:system) { FactoryGirl.create(:system, project: project) }
    let(:environment) do
      @blueprint_history = BlueprintHistory.eager_load(:pattern_snapshots).find(blueprint_history)
      environment = FactoryGirl.create(:environment, system: system, blueprint_history: @blueprint_history, candidates_attributes: [FactoryGirl.attributes_for(:candidate, cloud: cloud)])
      system.update_columns(primary_environment_id: environment.id)
      environment
    end
    let(:stack) { environment.stacks.first }
    let(:candidate) { environment.candidates.first }
    let(:application) do
      @system = System.eager_load(:project).find(system)
      FactoryGirl.create(:application, system: @system)
    end
    let(:application_history) do
      @application = Application.eager_load(:system).find(application)
      FactoryGirl.create(:application_history, application: @application)
    end

    let(:role) { FactoryGirl.create(:role, project: project) }
    let(:audit) { FactoryGirl.create(:audit, project_id: project.id) }
  end
end
