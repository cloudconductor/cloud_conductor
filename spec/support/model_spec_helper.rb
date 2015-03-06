module ModelSpecHelper
  shared_context 'default_resources' do
    let(:project) { FactoryGirl.create(:project) }
    let(:cloud) { FactoryGirl.create(:cloud, project: project) }
    let(:system) { FactoryGirl.create(:system, project: project) }
    let(:blueprint) { FactoryGirl.create(:blueprint, project: project, patterns_attributes: [FactoryGirl.attributes_for(:pattern, :platform)]) }
    let(:pattern) { blueprint.patterns.first }
    let(:image) { FactoryGirl.create(:image, base_image: base_image, pattern: pattern, cloud: cloud) }
    let(:base_image) { FactoryGirl.create(:base_image, cloud: cloud) }
    let(:environment) { FactoryGirl.create(:environment, system: system, blueprint: blueprint, candidates_attributes: [FactoryGirl.attributes_for(:candidate, cloud: cloud)]) }
    let(:stack) { environment.stacks.first }
    let(:candidate) { environment.candidates.first }
    let(:application) { FactoryGirl.create(:application, system: system) }
    let(:application_history) { FactoryGirl.create(:application_history, application: application) }
  end
end
