module ModelSpecHelper
  shared_context 'default_resources' do
    let(:project) { FactoryGirl.create(:project) }
    let(:cloud) { FactoryGirl.create(:cloud, project: project) }
    let(:base_image) { cloud.base_images.first || FactoryGirl.create(:base_image, cloud: cloud) }
    let(:blueprint) do
      blueprint = FactoryGirl.create(:blueprint, project: project, patterns_attributes: [FactoryGirl.attributes_for(:pattern, :platform)])
      blueprint.patterns.each do |pattern|
        FactoryGirl.create(:image, pattern: pattern, base_image: base_image, cloud: cloud)
      end
      blueprint
    end
    let(:pattern) { blueprint.patterns.first }
    let(:image) { pattern.images.first }
    let(:system) { FactoryGirl.create(:system, project: project) }
    let(:environment) { FactoryGirl.create(:environment, system: system, blueprint: blueprint, candidates_attributes: [FactoryGirl.attributes_for(:candidate, cloud: cloud)]) }
    let(:stack) { environment.stacks.first }
    let(:candidate) { environment.candidates.first }
    let(:application) { FactoryGirl.create(:application, system: system) }
    let(:application_history) { FactoryGirl.create(:application_history, application: application) }
  end
end
