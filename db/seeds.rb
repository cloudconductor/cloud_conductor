# -*- coding: utf-8 -*-
# Copyright 2014 TIS Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

os = OperatingSystem.new
os.name = 'centos'
os.version = '6.5'
os.save!

cloud_aws = Cloud.new
cloud_aws.name = 'cloud_aws'
cloud_aws.type = 'aws'
cloud_aws.entry_point = 'ap-northeast-1'
cloud_aws.key = '1234567890abcdef'
cloud_aws.secret = '1234567890abcdef'
cloud_aws.tenant_id = nil
cloud_aws.template = <<-EOS
  {
    "name": "{{target `name`}}",
    "type": "amazon-ebs",
    "access_key": "{{cloud `key`}}",
    "secret_key": "{{cloud `secret`}}",
    "region": "ap-northeast-1",
    "instance_type": "m1.small",
    "ssh_username": "{{target `ssh_username`}}",
    "source_ami": "{{target `source_image`}}",
    "ami_name": "{{operating_system `name`}}-{{user `role`}}-{{uuid}}",
    "tags": {
      "Name": "{{operating_system `name`}}-{{user `role`}}"
    }
  }
EOS
cloud_aws.targets.build(operating_system: os, source_image: 'ami-12345678', ssh_username: 'ec2-user')
cloud_aws.save!

cloud_openstack = Cloud.new
cloud_openstack.name = 'cloud_openstack'
cloud_openstack.type = 'openstack'
cloud_openstack.entry_point = 'http://127.0.0.1:5000/'
cloud_openstack.key = '1234567890abcdef'
cloud_openstack.secret = '1234567890abcdef'
cloud_openstack.tenant_id = '1234567890abcdef'
cloud_openstack.template = <<-EOS
  {
    "name": "{{target `name`}}",
    "type": "openstack",
    "username": "{{cloud `key`}}",
    "password": "{{cloud `secret`}}",
    "tenant_id": "{{cloud `tenant_id`}}",
    "provider": "{{cloud `entry_point`}}v2.0/tokens",
    "region": "RegionOne",
    "flavor": "2",
    "source_image": "{{target `source_image`}}",
    "image_name": "{{operating_system `name`}}-{{user `role`}}",
    "ssh_username": "{{target `ssh_username`}}",
    "use_floating_ip": "true",
    "floating_ip_pool": "public"
  }
EOS
cloud_openstack.targets.build(operating_system: os, source_image: '12345678-1234-1234-1234-1234567890ab', ssh_username: 'ec2-user')
cloud_openstack.save!

# cloud_dummy = Cloud.new
# cloud_dummy.name = 'cloud_dummy'
# cloud_dummy.type = 'dummy'
# cloud_dummy.entry_point = 'http://127.0.0.1:5000/'
# cloud_dummy.key = '1234567890abcdef'
# cloud_dummy.secret = '1234567890abcdef'
# cloud_dummy.tenant_id = '1234567890abcdef'
# cloud_dummy.save!
