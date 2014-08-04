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
module CloudConductor
  describe PackerClient do
    describe '#build' do
      before do
        options = {
          aws_access_key: 'dummy_access_key',
          aws_secret_key: 'dummy_secret_key',
          openstack_host: 'dummy_host',
          openstack_username: 'dummy_user',
          openstack_password: 'dummy_password',
          openstack_tenant_id: 'dummy_tenant_id',
          packer_path: '/opt/packer/packer',
          packer_json_path: '/tmp/packer.json'
        }
        @client = PackerClient.new options
        @clouds = %w(aws openstack)
        @oss = %w(centos ubuntu)
        @role = 'nginx'
      end

      it 'will execute packer that specified with repository_url and revision option' do
        vars = []
        vars << "-var 'repository_url=http://example.com'"
        vars << "-var 'revision=dummy_revision'"

        @client.should_receive(:systemu).with(include(*vars))
        @client.build('http://example.com', 'dummy_revision', @clouds, @oss, 'nginx')
      end

      it 'will execute packer that specified with cloud and OS option' do
        only = (@clouds.product @oss).map { |cloud, os| "#{cloud}-#{os}" }.join(',')
        vars = []
        vars << "-only=#{only}"

        @client.should_receive(:systemu).with(include(*vars))
        @client.build('http://example.com', 'dummy_revision', @clouds, @oss, 'nginx')
      end

      it 'will execute packer that specified with Role option' do
        vars = []
        vars << "-var 'role=nginx'"

        @client.should_receive(:systemu).with(include(*vars))
        @client.build('http://example.com', 'dummy_revision', @clouds, @oss, 'nginx')
      end

      it 'will execute packer that specified with aws_access_key and aws_secret_key option' do
        vars = []
        vars << "-var 'aws_access_key=dummy_access_key'"
        vars << "-var 'aws_secret_key=dummy_secret_key'"

        @client.should_receive(:systemu).with(include(*vars))
        @client.build('http://example.com', 'dummy_revision', @clouds, @oss, @role)
      end

      it 'will execute packer that specified with openstack host, username, password and tenant_id option' do
        vars = []
        vars << "-var 'openstack_host=dummy_host'"
        vars << "-var 'openstack_username=dummy_user'"
        vars << "-var 'openstack_password=dummy_password'"
        vars << "-var 'openstack_tenant_id=dummy_tenant_id'"

        @client.should_receive(:systemu).with(include(*vars))
        @client.build('http://example.com', 'dummy_revision', @clouds, @oss, @role)
      end

      it 'will execute packer that specified with packer_path and packer_json_path option' do
        pattern = %r{^/opt/packer/packer.*/tmp/packer.json$}

        @client.should_receive(:systemu).with(pattern)
        @client.build('http://example.com', 'dummy_revision', @clouds, @oss, @role)
      end
    end
  end
end
