FactoryGirl.define do
  factory :base_image, class: BaseImage do
    cloud { build(:cloud, :aws) }
    os_version 'default'
    ssh_username 'ec2-user'
    source_image SecureRandom.uuid
  end
end
