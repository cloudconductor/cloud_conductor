FactoryGirl.define do
  factory :base_image, class: BaseImage do
    cloud { create(:cloud, :aws) }
    os 'CentOS-6.5'
    ssh_username 'ec2-user'
    source_image SecureRandom.uuid
  end
end
