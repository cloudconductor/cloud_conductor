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

cloud_aws = Cloud.new
cloud_aws.name = 'cloud-aws'
cloud_aws.cloud_type = 'aws'
cloud_aws.key = '1234567890abcdef'
cloud_aws.secret = '1234567890abcdef'
cloud_aws.tenant_id = nil
cloud_aws.save!

cloud_openstack = Cloud.new
cloud_openstack.name = 'cloud-openstack'
cloud_openstack.cloud_type = 'openstack'
cloud_openstack.key = '1234567890abcdef'
cloud_openstack.secret = '1234567890abcdef'
cloud_openstack.tenant_id = '1234567890abcdef'
cloud_openstack.save!
