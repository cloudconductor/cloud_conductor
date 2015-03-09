FactoryGirl.define do
  factory :blueprint, class: Blueprint do
    project
    sequence(:name) { |n| "blueprint-#{n}" }
    description 'blueprint description'
    patterns_attributes do
      [FactoryGirl.attributes_for(:pattern, :platform),
       FactoryGirl.attributes_for(:pattern, :optional)]
    end

    before(:create) do
      Pattern.skip_callback :save, :before, :execute_packer
    end

    after(:create) do
      Pattern.set_callback :save, :before, :execute_packer, if: -> { url_changed? || revision_changed? }
    end
  end
end
