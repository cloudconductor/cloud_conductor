FactoryGirl.define do
  factory :base_image, class: BaseImage do
    cloud { create(:cloud_aws) }
    operating_system 'CentOS-6.5'
    source_image SecureRandom.uuid
  end
end
