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
      allow_any_instance_of(Pattern).to receive(:set_metadata_from_repository)

      options = {
        packer_path: '/opt/packer/packer',
        template_path: '/tmp/packer.json',
        cloudconductor_root: '/opt/cloudconductor',
        variables: {
          aws_access_key: 'dummy_access_key',
          aws_secret_key: 'dummy_secret_key',
          openstack_host: 'dummy_host',
          openstack_username: 'dummy_user',
          openstack_password: 'dummy_password',
          openstack_tenant_id: 'dummy_tenant_id'
        }
      }
      @client = PackerClient.new options
    end

    describe '#initialize' do
      it 'set default option when initialized without options' do
        packer_path = CloudConductor::Config.packer.path
        template_path = File.expand_path('../../../config/packer.json', File.dirname(__FILE__))

        client = PackerClient.new
        expect(client.instance_variable_get(:@packer_path)).to eq(packer_path)
        expect(client.instance_variable_get(:@template_path)).to eq(template_path)
      end

      it 'update options with specified option when initialized with some options' do
        client = PackerClient.new packer_path: 'dummy_path', template_path: 'dummy_json_path'
        expect(client.instance_variable_get(:@packer_path)).to eq('dummy_path')
        expect(client.instance_variable_get(:@template_path)).to eq('dummy_json_path')
      end
    end

    describe '#build' do
      before do
        @parameters = {
          repository_url: 'http://example.com',
          revision: 'dummy_revision',
          role: 'nginx',
          pattern_name: 'dummy_pattern_name',
          consul_secret_key: 'dummy key'
        }

        allow(@client).to receive(:create_json).and_return('/tmp/packer/7915c5f6-33b3-4c6d-b66b-521f61a82e8b.json')
        allow(@client).to receive(:build_command)
        allow(Thread).to receive(:new).and_yield
        allow(@client).to receive(:systemu).and_return([double('status', 'success?' => true), '', ''])
        allow(IO).to receive(:read).and_return('')
        allow(@client).to receive(:parse).and_return('dummy' => { status: :SUCCESS })
        allow(FileUtils).to receive(:rm)

        @images = []
        @images << FactoryGirl.create(:image)
        @images << FactoryGirl.create(:image)
      end

      it 'will call #create_json to create json file' do
        expect(@client).to receive(:create_json).with(@images)
        @client.build(@images, @parameters)
      end

      it 'will call #build_command to create packer command' do
        expected_parameters = @parameters.merge(packer_json_path: '/tmp/packer/7915c5f6-33b3-4c6d-b66b-521f61a82e8b.json')
        expect(@client).to receive(:build_command).with(expected_parameters)
        @client.build(@images, @parameters)
      end

      it 'will yield block with parsed results' do
        expect { |b| @client.build(@images, @parameters, &b) }.to yield_with_args('dummy' => { status: :SUCCESS })
      end

      it 'remove temporary json for packer when finished block without error' do
        expect(FileUtils).to receive(:rm).with('/tmp/packer/7915c5f6-33b3-4c6d-b66b-521f61a82e8b.json')
        @client.build(@images, @parameters)
      end

      it 'remove temporary json for packer when some errors occurred while yielding block' do
        expect(FileUtils).to receive(:rm).with('/tmp/packer/7915c5f6-33b3-4c6d-b66b-521f61a82e8b.json')

        @client.build(@images, @parameters) { fail }
        expect(@images.map(&:status)).to all(eq(:ERROR))
      end

      it 'set status to ERROR on images when exit status of packer is non zero' do
        status_stub = double('status', 'success?' => false, exitstatus: 5)
        allow(@client).to receive(:systemu).and_return([status_stub, '', ''])
        @client.build(@images, @parameters)
        expect(@images.map(&:status)).to all(eq(:ERROR))
      end

      it 'set status to ERROR on images when some error occurred while executing packer' do
        allow(@client).to receive(:systemu).and_raise
        @client.build(@images, @parameters)
        expect(@images.map(&:status)).to all(eq(:ERROR))
      end
    end

    describe '#create_json' do
      before do
        @images = []
        @images << FactoryGirl.create(:image)
        @images << FactoryGirl.create(:image)

        allow(Dir).to receive(:exist?).and_return true
        allow(FileUtils).to receive(:mkdir_p)
        allow(@client).to receive(:open).and_return('{ "variables": [], "builders": [] }')
        allow(File).to receive(:open).and_yield(double(:file, write: nil))
        @images.each { |image| allow(image.base_image).to receive(:builder).and_return(dummy: 'dummy_value') }
      end

      it 'create directory to store packer.json if directory does not exist' do
        allow(Dir).to receive(:exist?).and_return false
        expect(FileUtils).to receive(:mkdir_p).with(%r{/tmp/packer$})
        @client.send(:create_json, @images)
      end

      it 'return json path that is created by #create_json in tmp directory' do
        path = @client.send(:create_json, @images)
        expect(path).to match(%r{/[0-9a-z\-]{36}.json$})
      end

      it 'write valid json to temporary packer.json' do
        expected_content = satisfy do |content|
          json = JSON.parse(content, symbolize_names: true)
          expect(json.keys).to match_array([:variables, :builders])
          expect(json[:builders].size).to eq(@images.size)
          json[:builders].each do |builder|
            expect(builder).to eq(dummy: 'dummy_value')
          end
        end

        file = double(:file)
        expect(file).to receive(:write).with(expected_content)

        allow(File).to receive(:open).and_yield(file)
        @client.send(:create_json, @images)
      end
    end

    describe '#build_command' do
      before do
        @parameters = {
          repository_url: 'http://example.com/default',
          revision: 'default_revision',
          role: 'nginx',
          pattern_name: 'default_pattern_name',
          consul_secret_key: 'default_key',
          packer_json_path: '/tmp/packer/7915c5f6-33b3-4c6d-b66b-521f61a82e8b.json'
        }
      end

      it 'return command with repository_url and revision' do
        vars = []
        vars << '-var repository_url=http://example.com'
        vars << '-var revision=dummy_revision'

        @parameters.merge!(repository_url: 'http://example.com', revision: 'dummy_revision')
        command = @client.send(:build_command, @parameters)
        expect(command).to include(*vars)
      end

      it 'return command with cloudconductor_root' do
        vars = []
        vars << '-var cloudconductor_root=/opt/cloudconductor'

        command = @client.send(:build_command, @parameters)
        expect(command).to include(*vars)
      end

      it 'return command with Role option' do
        vars = []
        vars << '-var role=nginx'

        command = @client.send(:build_command, @parameters)
        expect(command).to include(*vars)
      end

      it 'return command with image_name option' do
        vars = []
        vars << '-var image_name=nginx-dummy'

        @parameters.merge!(role: 'nginx, dummy')
        command = @client.send(:build_command, @parameters)
        expect(command).to include(*vars)
      end

      it 'return command with aws_access_key and aws_secret_key option' do
        vars = []
        vars << '-var aws_access_key=dummy_access_key'
        vars << '-var aws_secret_key=dummy_secret_key'

        command = @client.send(:build_command, @parameters)
        expect(command).to include(*vars)
      end

      it 'return command with openstack host, username, password and tenant_id option' do
        vars = []
        vars << '-var openstack_host=dummy_host'
        vars << '-var openstack_username=dummy_user'
        vars << '-var openstack_password=dummy_password'
        vars << '-var openstack_tenant_id=dummy_tenant_id'

        command = @client.send(:build_command, @parameters)
        expect(command).to include(*vars)
      end

      it 'return command with packer_path and packer_json_path option' do
        pattern = %r{^/opt/packer/packer.*/tmp/packer/7915c5f6-33b3-4c6d-b66b-521f61a82e8b.json$}

        command = @client.send(:build_command, @parameters)
        expect(command).to match(pattern)
      end

      it 'doesn\'t occur any error when does NOT specified variables option' do
        client = PackerClient.new
        client.send(:build_command, @parameters)
      end

      it 'return command with consul_secret_key that is created by `consul keygen`' do
        vars = []
        vars << '-var consul_secret_key=dummy_key'

        @parameters.merge!(consul_secret_key: 'dummy_key')
        command = @client.send(:build_command, @parameters)
        expect(command).to include(*vars)
      end
    end

    describe '#parse' do
      before do
        @cloud_aws = FactoryGirl.create(:cloud, :aws, name: 'aws')
        @cloud_openstack = FactoryGirl.create(:cloud, :openstack, name: 'openstack')
        @base_image_aws = FactoryGirl.create(:base_image, cloud: @cloud_aws, os: 'centos')
        @base_image_openstack = FactoryGirl.create(:base_image, cloud: @cloud_openstack, os: 'centos')
      end

      def load_csv(path)
        csv_path = File.expand_path("../../features/packer_results/#{path}", File.dirname(__FILE__))
        File.open(csv_path).read
      end

      it 'return success status and image of all builders when success all builders' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_aws, base_image: @base_image_aws, role: 'web')
        images << FactoryGirl.create(:image, cloud: @cloud_openstack, base_image: @base_image_openstack, role: 'web')

        result = @client.send(:parse, load_csv('success.csv'), images)
        expect(result.keys).to match_array(%w(aws-centos----web openstack-centos----web))

        aws = result['aws-centos----web']
        expect(aws[:status]).to eq(:SUCCESS)
        expect(aws[:image]).to match(/ami-[0-9a-f]{8}/)

        openstack = result['openstack-centos----web']
        expect(openstack[:status]).to eq(:SUCCESS)
        expect(openstack[:image]).to match(/[0-9a-f\-]{36}/)
      end

      it 'return error status and error message about aws builder when source image does not exists while build on aws' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_aws, base_image: @base_image_aws, role: 'web')

        result = @client.send(:parse, load_csv('error_aws_image_not_found.csv'), images)
        expect(result.keys).to match_array(%w(aws-centos----web))

        aws = result['aws-centos----web']
        expect(aws[:status]).to eq(:ERROR)
        expect(aws[:image]).to be_nil
        expect(aws[:message]).to match(/Error querying AMI: The image id '\[ami-[0-9a-f]{8}\]' does not exist \(InvalidAMIID.NotFound\)/)
      end

      it 'return error status and error message about aws builder when SSH connecetion failed while build on aws' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_aws, base_image: @base_image_aws, role: 'web')

        result = @client.send(:parse, load_csv('error_aws_ssh_faild.csv'), images)
        expect(result.keys).to match_array(%w(aws-centos----web))

        aws = result['aws-centos----web']
        expect(aws[:status]).to eq(:ERROR)
        expect(aws[:image]).to be_nil
        expect(aws[:message]).to eq('Error waiting for SSH: ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain')
      end

      it 'return error status and error message about aws builder when an error has occurred while provisioning' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_aws, base_image: @base_image_aws, role: 'web')

        result = @client.send(:parse, load_csv('error_aws_provisioners_faild.csv'), images)
        expect(result.keys).to match_array(%w(aws-centos----web))

        aws = result['aws-centos----web']
        expect(aws[:status]).to eq(:ERROR)
        expect(aws[:image]).to be_nil
        expect(aws[:message]).to match('Script exited with non-zero exit status: \d+')
      end

      it 'return error status and error message about openstack builder when source image does not exists while build on openstack' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_openstack, base_image: @base_image_openstack, role: 'web')

        result = @client.send(:parse, load_csv('error_openstack_image_not_found.csv'), images)
        expect(result.keys).to match_array(%w(openstack-centos----web))

        openstack = result['openstack-centos----web']
        expect(openstack[:status]).to eq(:ERROR)
        expect(openstack[:image]).to be_nil
        expect(openstack[:message]).to match(%r{Error launching source server: Expected HTTP response code \[202\] when accessing URL\(http://[0-9\.]+:8774/v2/[0-9a-f]+/servers\); got 400 instead with the following body:\\n\{"badRequest": \{"message": "Can not find requested image", "code": 400\}\}})
      end

      it 'return error status and error message about openstack builder when SSH connecetion failed while build on openstack' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_openstack, base_image: @base_image_openstack, role: 'web')

        result = @client.send(:parse, load_csv('error_openstack_ssh_faild.csv'), images)
        expect(result.keys).to match_array(%w(openstack-centos----web))

        openstack = result['openstack-centos----web']
        expect(openstack[:status]).to eq(:ERROR)
        expect(openstack[:image]).to be_nil
        expect(openstack[:message]).to eq('Error waiting for SSH: ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain')
      end

      it 'return error status and error message about openstack builder when an error has occurred while provisioning' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_openstack, base_image: @base_image_openstack, role: 'web')

        result = @client.send(:parse, load_csv('error_openstack_provisioners_faild.csv'), images)
        expect(result.keys).to match_array(%w(openstack-centos----web))

        openstack = result['openstack-centos----web']
        expect(openstack[:status]).to eq(:ERROR)
        expect(openstack[:image]).to be_nil
        expect(openstack[:message]).to match('Script exited with non-zero exit status: \d+')
      end

      it 'return error status and error message about all builders when multiple builders failed' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_aws, base_image: @base_image_aws, role: 'web')
        images << FactoryGirl.create(:image, cloud: @cloud_openstack, base_image: @base_image_openstack, role: 'web')

        result = @client.send(:parse, load_csv('error_concurrency.csv'), images)
        expect(result.keys).to match_array(%w(aws-centos----web openstack-centos----web))

        aws = result['aws-centos----web']
        expect(aws[:status]).to eq(:ERROR)
        expect(aws[:image]).to be_nil
        expect(aws[:message]).to match('Script exited with non-zero exit status: \d+')

        openstack = result['openstack-centos----web']
        expect(openstack[:status]).to eq(:ERROR)
        expect(openstack[:image]).to be_nil
        expect(openstack[:message]).to match('Script exited with non-zero exit status: \d+')
      end

      it 'return success status and image when pattern has comman separated roles' do
        images = []
        images << FactoryGirl.create(:image, cloud: @cloud_aws, base_image: @base_image_aws, role: 'web, ap')

        result = @client.send(:parse, load_csv('success_with_multiple_roles.csv'), images)
        expect(result.keys).to match_array(%w(aws-centos----web-ap))

        aws = result['aws-centos----web-ap']
        expect(aws[:status]).to eq(:SUCCESS)
        expect(aws[:image]).to match(/ami-[0-9a-f]{8}/)
      end
    end
  end
end
