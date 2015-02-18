FactoryGirl.define do
  factory :blueprint, class: Blueprint do
    sequence(:name) { |n| "blueprint-#{n}" }

    before(:create) do
      Pattern.skip_callback :save, :before, :execute_packer
    end

    after(:create) do
      Pattern.set_callback :save, :before, :execute_packer, if: -> { url_changed? || revision_changed? }
    end
  end
end
