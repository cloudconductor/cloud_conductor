FactoryGirl.define do
  factory :blueprint, class: Blueprint do
    project
    sequence(:name) { |n| "blueprint-#{n}" }
    description 'blueprint description'
    patterns_attributes do
      [FactoryGirl.attributes_for(:pattern, :platform),
       FactoryGirl.attributes_for(:pattern, :optional)]
    end

    before(:create) do |blueprint|
      Pattern.skip_callback :save, :before, :execute_packer
      Blueprint.skip_callback :create, :before, :update_consul_secret_key
      blueprint.consul_secret_key = SecureRandom.base64(16)
    end

    after(:create) do
      Pattern.set_callback :save, :before, :execute_packer, if: -> { url_changed? || revision_changed? }
      Blueprint.set_callback :create, :before, :update_consul_secret_key
    end
  end
end
