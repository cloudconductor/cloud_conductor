FactoryGirl.define do
  factory :base_image, class: BaseImage do
    cloud { build(:cloud, :aws) }
    platform 'centos'
    sequence(:platform_version, &:to_s)
    ssh_username 'centos'
    source_image SecureRandom.uuid
  end
end
