FactoryGirl.define do
  factory :base_image, class: BaseImage do
    operating_system 'CentOS-6.5'
    source_image SecureRandom.uuid
  end
end
