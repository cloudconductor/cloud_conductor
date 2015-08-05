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
describe Pattern do
  include_context 'default_resources'

  let(:cloned_path) { File.expand_path("./tmp/patterns/#{SecureRandom.uuid}") }

  before do
    @pattern = Pattern.new
    @pattern.name = 'pattern_name'
    @pattern.blueprint = blueprint
    @pattern.blueprint.patterns.clear
    @pattern.blueprint.patterns << @pattern
    @pattern.url = 'http://example.com/pattern.git'

    allow(@pattern).to receive(:execute_packer)
  end

  describe '#initialize' do
    it 'set protocol to git' do
      expect(@pattern.protocol).to eq('git')
    end
  end

  describe '#save' do
    it 'call #execute_packer' do
      expect(@pattern).to receive(:execute_packer)
      @pattern.save!
    end

    it 'create with valid parameters' do
      expect { @pattern.save! }.to change { Pattern.count }.by(1)
    end
  end

  describe '#destroy' do
    before do
      allow_any_instance_of(Image).to receive(:destroy_image).and_return(true)
    end

    it 'delete pattern record' do
      @pattern.save!
      expect { @pattern.destroy }.to change { Pattern.count }.by(-1)
    end

    it 'delete all image records' do
      @pattern.images << FactoryGirl.create(:image, pattern: @pattern)
      @pattern.images << FactoryGirl.create(:image, pattern: @pattern)

      expect(@pattern.images.size).to eq(2)
      expect { @pattern.destroy }.to change { Image.count }.by(-2)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@pattern.valid?).to be_truthy
    end

    it 'returns false when blueprint is unset' do
      @pattern.blueprint = nil
      expect(@pattern.valid?).to be_falsey
    end

    it 'returns false when url is unset' do
      @pattern.url = nil
      expect(@pattern.valid?).to be_falsey
    end

    it 'returns false when url is invalid URL' do
      @pattern.url = 'invalid url'
      expect(@pattern.valid?).to be_falsey
    end
  end

  describe '#status' do
    before do
      @pattern.images << FactoryGirl.create(:image, pattern: @pattern, status: :PROGRESS)
      @pattern.images << FactoryGirl.create(:image, pattern: @pattern, status: :PROGRESS)
      @pattern.images << FactoryGirl.create(:image, pattern: @pattern, status: :PROGRESS)
    end

    it 'return status that integrated status over all images' do
      expect(@pattern.status).to eq(:PROGRESS)
    end

    it 'return :PROGRESS when least one image has progress status' do
      @pattern.images[0].status = :CREATE_COMPLETE

      expect(@pattern.status).to eq(:PROGRESS)
    end

    it 'return :ERROR when pattern hasn\'t images' do
      @pattern.images.delete_all
      expect(@pattern.status).to eq(:ERROR)
    end

    it 'return :CREATE_COMPLETE when all images have CREATE_COMPLETE status' do
      @pattern.images[0].status = :CREATE_COMPLETE
      @pattern.images[1].status = :CREATE_COMPLETE
      @pattern.images[2].status = :CREATE_COMPLETE

      expect(@pattern.status).to eq(:CREATE_COMPLETE)
    end

    it 'return error when least one image has error status' do
      @pattern.images[0].status = :CREATE_COMPLETE
      @pattern.images[1].status = :PROGRESS
      @pattern.images[2].status = :ERROR

      expect(@pattern.status).to eq(:ERROR)
    end
  end

  describe '#set_metadata_from_repository' do
    before do
      allow(@pattern).to receive(:set_metadata_from_repository).and_call_original
      allow(@pattern).to receive(:clone_repository).and_yield('/tmp/patterns')
      allow(@pattern).to receive(:collect_roles)
      allow(@pattern).to receive(:load_template).and_return(template_key: 'template_value')
      allow(@pattern).to receive(:load_metadata).and_return(metadata_key: 'metadata_value')
      allow(@pattern).to receive(:update_metadata)
    end

    it 'call clone_repository' do
      expect(@pattern).to receive(:clone_repository)

      @pattern.set_metadata_from_repository
    end

    it 'call load_template' do
      expect(@pattern).to receive(:load_template).with('/tmp/patterns')

      @pattern.set_metadata_from_repository
    end

    it 'call load_metadata' do
      expect(@pattern).to receive(:load_metadata).with('/tmp/patterns')

      @pattern.set_metadata_from_repository
    end

    it 'call update_metadata' do
      expect(@pattern).to receive(:update_metadata).with('/tmp/patterns', metadata_key: 'metadata_value')

      @pattern.set_metadata_from_repository
    end
  end

  describe '#execute_packer' do
    before do
      allow(@pattern).to receive(:execute_packer).and_call_original
      allow(@pattern).to receive(:create_images)
      allow(@pattern).to receive(:template).and_return({})

      @pattern.instance_variable_set(:@roles, ['dummy'])
    end

    it 'will call sub-routine with secret key' do
      expect(@pattern).to receive(:create_images).with('dummy')

      @pattern.send(:execute_packer)
    end
  end

  describe '#clone_repository' do
    before do
      allow(Dir).to receive(:chdir).and_yield
      allow(FileUtils).to receive(:rm_r)
      status = double('status', success?: true)
      allow(Open3).to receive(:capture3).and_return(['', '', status])
    end

    it 'will raise error when block does not given' do
      expect { @pattern.send(:clone_repository) }.to raise_error('Pattern#clone_repository needs block')
    end

    it 'will clone repository to temporary directory' do
      expect(Open3).to receive(:capture3).with('git', 'clone', @pattern.url, %r(.*tmp\/patterns\/[a-f0-9-]{36}))
      @pattern.send(:clone_repository) {}
    end

    it 'will change current directory to cloned repoitory and restore current directory after exit' do
      expect(Dir).to receive(:chdir).with(%r{/tmp/patterns/[a-f0-9-]{36}}).and_yield
      @pattern.send(:clone_repository) {}
    end

    it 'will change branch to specified revision when revision has specified' do
      expect(Open3).to receive(:capture3).with('git', 'checkout', 'dummy')

      @pattern.revision = 'dummy'
      @pattern.send(:clone_repository) {}
    end

    it 'won\'t change branch when revision is nil' do
      command = /git checkout/
      expect(Open3).not_to receive(:capture3).with(command)

      @pattern.send(:clone_repository) {}
    end

    it 'will yield given block with path of cloned repository' do
      expect { |b| @pattern.send(:clone_repository, &b) }.to yield_with_args(%r{/tmp/patterns/[a-f0-9-]{36}})
    end

    it 'will remove cloned repository after yield block' do
      expect(FileUtils).to receive(:rm_r).with(%r{/tmp/patterns/[a-f0-9-]{36}}, force: true)
      @pattern.send(:clone_repository) {}
    end

    it 'will remove cloned repository when some errors occurred while yielding block' do
      expect(FileUtils).to receive(:rm_r).with(%r{/tmp/patterns/[a-f0-9-]{36}}, force: true)
      expect { @pattern.send(:clone_repository) { fail } }.to raise_error
    end
  end

  describe '#load_template' do
    it 'will load template.json that is in cloned repository' do
      template = double('File', read: '{ "key": "value" }')
      template_path = %r(tmp/patterns/[a-f0-9-]{36}/template.json)
      allow(File).to receive(:open).with(template_path).and_return(template)

      result = @pattern.send(:load_template, cloned_path)
      expect(result).to eq('key' => 'value')
    end
  end

  describe '#load_metadata' do
    it 'will load metadata.yml that is in cloned repository' do
      metadata = { name: 'name' }
      path_pattern = %r(tmp/patterns/[a-f0-9-]{36}/metadata.yml)
      expect(YAML).to receive(:load_file).with(path_pattern).and_return(metadata)

      result = @pattern.send(:load_metadata, cloned_path)
      expect(result).to eq(metadata.with_indifferent_access)
    end
  end

  describe '#collect_roles' do
    it 'raise error when Resources does not exist' do
      expect { @pattern.send(:collect_roles, {}) }.to raise_error('Resources was not found')
    end

    it 'will load template.json and get role list' do
      template = {
        Resources: {
          Dummy1: {
            Type: 'AWS::EC2::Instance',
            Metadata: {
              Role: 'nginx'
            }
          },
          Dummy2: {
            Type: 'AWS::AutoScaling::LaunchConfiguration',
            Metadata: {
              Role: 'rails'
            }
          },
          Dummy3: {
            Type: 'AWS::EC2::Instance',
            Metadata: {
              Role: 'rails'
            }
          },
          Dummy4: {
            Type: 'AWS::EC2::Instance'
          }
        }
      }.with_indifferent_access

      roles = %w(nginx rails Dummy4)
      expect(@pattern.send(:collect_roles, template)).to match_array(roles)
    end
  end

  describe '#load_parameters' do
    it 'will load template.json and get parameters' do
      template = <<-EOS
        {
          "Parameters": {
            "KeyName" : {
              "Description" : "Name of an existing EC2/OpenStack KeyPair to enable SSH access to the instances",
              "Type" : "String",
              "MinLength" : "1",
              "MaxLength" : "255",
              "AllowedPattern" : "[\\x20-\\x7E]*",
              "ConstraintDescription" : "can contain only ASCII characters."
            },
            "SSHLocation" : {
              "Description" : "The IP address range that can be used to SSH to the EC2/OpenStack instances",
              "Type" : "String",
              "MinLength" : "9",
              "MaxLength" : "18",
              "Default" : "0.0.0.0/0",
              "AllowedPattern" : "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
              "ConstraintDescription" : "must be a valid IP CIDR range of the form x.x.x.x/x."
            },
            "WebInstanceType" : {
              "Description" : "WebServer instance type",
              "Type" : "String",
              "Default" : "t2.small"
            },
            "WebImageId" : {
              "Description" : "DBServer Image Id. This parameter is automatically filled by CloudConductor.",
              "Type" : "String"
            }
          }
        }
      EOS
      allow(File).to receive(:open).with(/template.json/).and_return(double('File', read: template))
      parameters = @pattern.send(:load_parameters, cloned_path)
      expect(parameters).to be_instance_of Hash
      expect(parameters.keys).to eq %w(KeyName SSHLocation WebInstanceType WebImageId)
      expect(parameters['KeyName']['MinLength']).to eq '1'
    end
  end

  describe '#update_metadata' do
    before do
      allow(Dir).to receive(:chdir).and_yield
      allow(@pattern).to receive(:load_parameters).and_return({})
      allow(@pattern).to receive(:load_backup_config).and_return({})
    end

    it 'update name attribute with name in metadata' do
      metadata = { name: 'name' }
      @pattern.send(:update_metadata, cloned_path, metadata)

      expect(@pattern.name).to eq('name')
    end

    it 'update type attribute with type in metadata' do
      metadata = { type: 'platform' }
      @pattern.send(:update_metadata, cloned_path, metadata)

      expect(@pattern.type).to eq('platform')
    end

    it 'update parameters attribute with parameters in template' do
      parameters = { keyname: { Type: 'String' } }
      allow(@pattern).to receive(:load_parameters).with(cloned_path).and_return(parameters)
      @pattern.send(:update_metadata, cloned_path, {})
      expect(@pattern.parameters).to eq(parameters.to_json)
    end

    it 'update revision attribute with latest commit hash' do
      hash = SecureRandom.hex(20)
      command = /git log --pretty=format:%H --max-count=1$/
      expect(@pattern).to receive(:`).with(command).and_return(hash)

      @pattern.send(:update_metadata, cloned_path, {})

      expect(@pattern.revision).to eq(hash)
    end
  end

  describe '#create_images' do
    before do
      FactoryGirl.create(:base_image, cloud: cloud)
      FactoryGirl.create(:base_image, cloud: cloud)
      allow(CloudConductor::PackerClient).to receive_message_chain(:new, :build).and_yield('dummy' => {})
      allow(@pattern).to receive(:update_images)
    end

    it 'create image each cloud and role' do
      expect { @pattern.send(:create_images, 'nginx') }.to change { @pattern.images.size }.by(1)
    end

    it 'will call PackerClient#build with url, revision, name of clouds, role, pattern_name and consul_secret_key' do
      parameters = {
        pattern_name: @pattern.name,
        patterns: {},
        role: 'nginx',
        consul_secret_key: @pattern.blueprint.consul_secret_key
      }
      parameters[:patterns][@pattern.name] = {
        url: @pattern.url,
        revision: @pattern.revision
      }

      packer_client = CloudConductor::PackerClient.new
      allow(CloudConductor::PackerClient).to receive(:new).and_return(packer_client)
      expect(packer_client).to receive(:build).with(anything, parameters)
      @pattern.send(:create_images, 'nginx')
    end

    it 'call #update_images with packer results' do
      expect(@pattern).to receive(:update_images).with('dummy' => {})
      @pattern.send(:create_images, 'nginx')
    end
  end

  describe '#update_images' do
    it 'update status of all images' do
      results = {
        'aws-CentOS-6.5----nginx' => {
          status: :SUCCESS,
          image: 'ami-12345678'
        },
        'openstack-CentOS-6.5----nginx' => {
          status: :ERROR,
          message: 'dummy_message'
        }
      }

      base_image_aws = FactoryGirl.create(:base_image, cloud: FactoryGirl.create(:cloud, :aws, name: 'aws'))
      base_image_openstack = FactoryGirl.create(:base_image, cloud: FactoryGirl.create(:cloud, :openstack, name: 'openstack'))
      FactoryGirl.create(:image, pattern: @pattern, base_image: base_image_aws, role: 'nginx')
      FactoryGirl.create(:image, pattern: @pattern, base_image: base_image_openstack, role: 'nginx')
      @pattern.send(:update_images, results)

      aws = Image.where(name: 'aws-CentOS-6.5----nginx').first
      expect(aws.status).to eq(:CREATE_COMPLETE)
      expect(aws.image).to eq('ami-12345678')
      expect(aws.message).to be_nil

      openstack = Image.where(name: 'openstack-CentOS-6.5----nginx').first
      expect(openstack.status).to eq(:ERROR)
      expect(openstack.image).to be_nil
      expect(openstack.message).to eq('dummy_message')
    end
  end

  describe '#filtered_parameters' do
    before do
      @pattern.parameters = <<-EOS
        {
          "KeyName" : {
            "Description" : "Name of an existing EC2/OpenStack KeyPair to enable SSH access to the instances",
            "Type" : "String"
          },
          "SSHLocation" : {
            "Description" : "The IP address range that can be used to SSH to the EC2/OpenStack instances",
            "Type" : "String"
          },
          "WebImageId" : {
            "Description" : "[computed] DBServer Image Id. This parameter is automatically filled by CloudConductor.",
            "Type" : "String"
          },
          "WebInstanceType" : {
            "Description" : "WebServer instance type",
            "Type" : "String"
          }
        }
      EOS
    end

    it 'return parameters without [computed] annotation' do
      parameters = @pattern.filtered_parameters
      expect(parameters.keys).to eq %w(KeyName SSHLocation WebInstanceType)
    end

    it 'return all parameters when specified option' do
      parameters = @pattern.filtered_parameters(true)
      expect(parameters.keys).to eq %w(KeyName SSHLocation WebImageId WebInstanceType)
    end
  end

  describe '#load_backup_config' do
    it 'load config/backup_restore.yml and return it' do
      expect(YAML).to receive(:load_file).with(/backup_restore.yml/).and_return(dummy: 'value')
      expect(@pattern.send(:load_backup_config, cloned_path)).to eq(dummy: 'value')
    end

    it 'return empty hash when config/backup_restore.yml does not exist' do
      expect(YAML).to receive(:load_file).with(/backup_restore.yml/).and_raise
      expect(@pattern.send(:load_backup_config, cloned_path)).to eq({})
    end
  end
end
