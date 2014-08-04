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
    end

    describe '#build' do
      before do
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

    describe '#parse' do
      def load_csv(path)
        results_path = File.expand_path('../../features/packer_results', File.dirname(__FILE__))
        csv_path = File.expand_path(path, results_path)

        File.open(csv_path).read
      end

      it 'return success status and image of all builders when success all builders' do
        csv = load_csv 'success.csv'
        result = @client.send(:parse, csv)
        expect(result.keys).to match_array(%w(aws-centos openstack-centos))

        aws = result['aws-centos']
        expect(aws[:status]).to eq(:success)
        expect(aws[:image]).to match(/ami-[0-9a-f]{8}/)

        openstack = result['openstack-centos']
        expect(openstack[:status]).to eq(:success)
        expect(openstack[:image]).to match(/[0-9a-f\-]{36}/)
      end

      it 'return error status and error message about aws builder when source image does not exists while build on aws' do
        csv = load_csv 'error_aws_image_not_found.csv'
        result = @client.send(:parse, csv)
        expect(result.keys).to match_array(%w(aws-centos))

        aws = result['aws-centos']
        expect(aws[:status]).to eq(:error)
        expect(aws[:image]).to be_nil
        expect(aws[:message]).to match(/Error querying AMI: The image id '\[ami-[0-9a-f]{8}\]' does not exist \(InvalidAMIID.NotFound\)/)
      end

      it 'return error status and error message about aws builder when SSH connecetion failed while build on aws' do
        csv = load_csv 'error_aws_ssh_faild.csv'
        result = @client.send(:parse, csv)
        expect(result.keys).to match_array(%w(aws-centos))

        aws = result['aws-centos']
        expect(aws[:status]).to eq(:error)
        expect(aws[:image]).to be_nil
        expect(aws[:message]).to eq('Error waiting for SSH: ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain')
      end

      it 'return error status and error message about aws builder when an error has occurred while provisioning' do
        csv = load_csv 'error_aws_provisioners_faild.csv'
        result = @client.send(:parse, csv)
        expect(result.keys).to match_array(%w(aws-centos))

        aws = result['aws-centos']
        expect(aws[:status]).to eq(:error)
        expect(aws[:image]).to be_nil
        expect(aws[:message]).to match('Script exited with non-zero exit status: \d+')
      end

      it 'return error status and error message about openstack builder when source image does not exists while build on openstack' do
        csv = load_csv 'error_openstack_image_not_found.csv'
        result = @client.send(:parse, csv)
        expect(result.keys).to match_array(%w(openstack-centos))

        openstack = result['openstack-centos']
        expect(openstack[:status]).to eq(:error)
        expect(openstack[:image]).to be_nil
        expect(openstack[:message]).to match(%r{Error launching source server: Expected HTTP response code \[202\] when accessing URL\(http://[0-9\.]+:8774/v2/[0-9a-f]+/servers\); got 400 instead with the following body:\\n==> openstack-centos: \{"badRequest": \{"message": "Invalid imageRef provided.", "code": 400\}\}})
      end

      it 'return error status and error message about openstack builder when SSH connecetion failed while build on openstack' do
        csv = load_csv 'error_openstack_ssh_faild.csv'
        result = @client.send(:parse, csv)
        expect(result.keys).to match_array(%w(openstack-centos))

        openstack = result['openstack-centos']
        expect(openstack[:status]).to eq(:error)
        expect(openstack[:image]).to be_nil
        expect(openstack[:message]).to eq('Error waiting for SSH: ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain')
      end

      it 'return error status and error message about openstack builder when an error has occurred while provisioning' do
        csv = load_csv 'error_openstack_provisioners_faild.csv'
        result = @client.send(:parse, csv)
        expect(result.keys).to match_array(%w(openstack-centos))

        openstack = result['openstack-centos']
        expect(openstack[:status]).to eq(:error)
        expect(openstack[:image]).to be_nil
        expect(openstack[:message]).to match('Script exited with non-zero exit status: \d+')
      end

      it 'return error status and error message about all builders when multiple builders failed' do
        csv = load_csv 'error_concurrency.csv'
        result = @client.send(:parse, csv)
        expect(result.keys).to match_array(%w(aws-centos openstack-centos))

        aws = result['aws-centos']
        expect(aws[:status]).to eq(:error)
        expect(aws[:image]).to be_nil
        expect(aws[:message]).to match('Script exited with non-zero exit status: \d+')

        openstack = result['openstack-centos']
        expect(openstack[:status]).to eq(:error)
        expect(openstack[:image]).to be_nil
        expect(openstack[:message]).to match('Script exited with non-zero exit status: \d+')
      end
    end
  end
end
