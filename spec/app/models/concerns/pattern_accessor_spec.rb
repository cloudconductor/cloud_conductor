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
describe PatternAccessor do
  include_context 'default_resources'

  let(:cloned_path) { File.expand_path("./tmp/patterns/#{SecureRandom.uuid}") }
  let(:url) { 'https://www.example.com/' }
  let(:revision) { 'develop' }
  let(:secret_key) { 'dummy' }
  let(:option) { { secret_key: secret_key, directory: cloned_path } }
  let(:archives_directory) { File.expand_path("./tmp/archives/#{SecureRandom.uuid}") }

  before do
    @accessor = Object.new
    @accessor.extend(PatternAccessor)
  end

  describe '#clone_repository' do
    before do
      allow(Dir).to receive(:chdir).and_yield
      allow(FileUtils).to receive(:rm_r)
      status = double('status', success?: true)
      allow(Open3).to receive(:capture3).and_return(['', '', status])
    end

    it 'will call clone_private_repository when secret_key is not blank' do
      options = { secret_key: secret_key }
      expect(:clone_private_repository)
      @accessor.clone_repository(url, revision, options) {}
    end

    it 'will clone with https repository to temporary directory' do
      expect(Open3).to receive(:capture3).with('git', 'clone', url, %r(.*tmp\/patterns\/[a-f0-9-]{36}))
      @accessor.clone_repository(url, revision) {}
    end

    it 'will change current directory to cloned repoitory and restore current directory after exit' do
      expect(Dir).to receive(:chdir).with(%r{/tmp/patterns/[a-f0-9-]{36}}).and_yield
      @accessor.clone_repository(url, revision) {}
    end

    it 'will change branch to specified revision when revision has specified' do
      expect(Open3).to receive(:capture3).with('git', 'checkout', revision)
      @accessor.clone_repository(url, revision) {}
    end

    it 'won\'t change branch when revision is nil' do
      expect(Open3).not_to receive(:capture3).with('git', 'checkout', anything)
      @accessor.clone_repository(url, nil) {}
    end

    it 'will yield given block with path of cloned repository' do
      expect { |b| @accessor.clone_repository(url, revision, &b) }.to yield_with_args(%r{/tmp/patterns/[a-f0-9-]{36}})
    end

    it 'will remove cloned repository after yield block' do
      expect(FileUtils).to receive(:rm_r).with(%r{/tmp/patterns/[a-f0-9-]{36}}, force: true)
      @accessor.clone_repository(url, revision) {}
    end

    it 'will remove cloned repository when some errors occurred while yielding block' do
      expect(FileUtils).to receive(:rm_r).with(%r{/tmp/patterns/[a-f0-9-]{36}}, force: true)
      expect { @accessor.clone_repository(url, revision) { fail } }.to raise_error(RuntimeError)
    end
    it 'will raise error when failed to clone repository' do
      status = double('status', success?: false)
      allow(Open3).to receive(:capture3).and_return(['', '', status])
      expect { @accessor.clone_repository(url, revision, option) {} }.to raise_error('An error has occurred while git clone')
    end
  end

  describe '#load_template' do
    it 'will load template.json that is in cloned repository' do
      template = double('File', read: '{ "key": "value" }')
      allow(File).to receive(:open).with("#{cloned_path}/template.json").and_return(template)

      result = @accessor.send(:load_template, cloned_path)
      expect(result).to eq('key' => 'value')
    end

    it 'return empty hash when template.json does not exist' do
      allow(File).to receive(:open).with("#{cloned_path}/template.json").and_raise(Errno::ENOENT)

      result = @accessor.send(:load_template, cloned_path)
      expect(result).to eq({})
    end
  end

  describe '#load_metadata' do
    it 'will load metadata.yml that is in cloned repository' do
      metadata = { name: 'name' }
      expect(YAML).to receive(:load_file).with("#{cloned_path}/metadata.yml").and_return(metadata)

      result = @accessor.send(:load_metadata, cloned_path)
      expect(result).to eq(metadata.with_indifferent_access)
    end
  end

  describe '#read_parameters' do
    it 'merge #read_cloud_formation_parameters and #read_terraform_parameters' do
      parameters1 = {
        'KeyName' => {
          'Description' => 'CF description'
        }
      }
      parameters2 = {
        'aws' => {
          'web_instance_type' => {
            'description' => 'Terraform description'
          }
        }
      }

      expected_parameters = {
        'cloud_formation' => {
          'KeyName' => {
            'Description' => 'CF description'
          }
        },
        'terraform' => {
          'aws' => {
            'web_instance_type' => {
              'description' => 'Terraform description'
            }
          }
        }
      }

      allow(@accessor).to receive(:read_cloud_formation_parameters).and_return(parameters1)
      allow(@accessor).to receive(:read_terraform_parameters).and_return(parameters2)

      expect(@accessor.send(:read_parameters, cloned_path)).to eq(expected_parameters)
    end
  end

  describe '#read_cloud_formation_parameters' do
    it 'will load template.json and get parameters' do
      json = <<-EOS
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
      template = double('File', read: json)
      allow(File).to receive(:open).with("#{cloned_path}/template.json").and_return(template)
      parameters = @accessor.send(:read_cloud_formation_parameters, cloned_path)
      expect(parameters).to be_is_a Hash
      expect(parameters.keys).to eq %w(KeyName SSHLocation WebInstanceType WebImageId)
      expect(parameters['KeyName']['MinLength']).to eq '1'
    end
  end

  describe '#read_terraform_parameters' do
    it 'read *.tf files and extract variables' do
      template1 = <<-EOS
        variable "vpc_id" {
          description = "VPC ID which is created by common network pattern."
        }
        variable "subnet_ids" {
          description = "Subnet ID which is created by common network pattern."
        }
        resource "aws_security_group" "web_security_group" {
          name = "WebSecurityGroup"
        }
      EOS

      template2 = <<-EOS
        variable "web_image" {
          description = "[computed] WebServer Image Id. This parameter is automatically filled by CloudConductor."
        }
        variable "web_instance_type" {
          description = "WebServer instance type"
          default = "t2.small"
        }
      EOS

      template3 = <<-EOS
        variable "web_image" {
          description = "[computed] WebServer Image Id. This parameter is automatically filled by CloudConductor."
        }
        variable "web_instance_type" {
          description = "WebServer instance type"
          default = "t2.small"
        }
      EOS

      expected_parameters = {
        'aws' => {
          'vpc_id' => {
            'description' => 'VPC ID which is created by common network pattern.'
          },
          'subnet_ids' => {
            'description' => 'Subnet ID which is created by common network pattern.'
          },
          'web_image' => {
            'description' => '[computed] WebServer Image Id. This parameter is automatically filled by CloudConductor.'
          },
          'web_instance_type' => {
            'description' => 'WebServer instance type',
            'default' => 't2.small'
          }
        },
        'openstack' => {
          'web_image' => {
            'description' => '[computed] WebServer Image Id. This parameter is automatically filled by CloudConductor.'
          },
          'web_instance_type' => {
            'description' => 'WebServer instance type',
            'default' => 't2.small'
          }
        }
      }

      allow(Dir).to receive(:glob).with("#{cloned_path}/templates/*")
        .and_yield("#{cloned_path}/templates/aws")
        .and_yield("#{cloned_path}/templates/openstack")

      allow(Dir).to receive(:glob).with("#{cloned_path}/templates/aws/*.tf")
        .and_return(["#{cloned_path}/templates/aws/variable1.tf", "#{cloned_path}/templates/aws/variable2.tf"])

      allow(Dir).to receive(:glob).with("#{cloned_path}/templates/openstack/*.tf")
        .and_return(["#{cloned_path}/templates/openstack/variable.tf"])

      allow(File).to receive(:read).with("#{cloned_path}/templates/aws/variable1.tf").and_return(template1)
      allow(File).to receive(:read).with("#{cloned_path}/templates/aws/variable2.tf").and_return(template2)
      allow(File).to receive(:read).with("#{cloned_path}/templates/openstack/variable.tf").and_return(template3)

      expect(@accessor.send(:read_terraform_parameters, cloned_path)).to eq(expected_parameters)
    end
  end

  describe '#read_roles' do
    it 'return empty array when Resources does not exist' do
      allow(@accessor).to receive(:load_template).and_return({})
      expect(@accessor.send(:read_roles, cloned_path)).to eq([])
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

      allow(@accessor).to receive(:load_template).and_return(template)
      roles = %w(nginx rails Dummy4)
      expect(@accessor.send(:read_roles, cloned_path)).to match_array(roles)
    end
  end

  describe '#clone_private_repository' do
    before do
      allow(FileUtils).to receive(:rm_r)
      allow(FileUtils).to receive(:mkdir_p)
      status = double('status', success?: true)
      allow(Open3).to receive(:capture3).and_return(['', '', status])
      allow(File).to receive(:open)
    end

    it 'will create temporary director for clone with ssh in the git_ssh directory ' do
      expect(FileUtils).to receive(:mkdir_p).with(%r(.*tmp\/git_ssh\/[a-f0-9-]{36}))
      @accessor.send(:clone_private_repository, secret_key, url, cloned_path)
    end

    it 'will call File.open method for create secret_key_file' do
      expect(File).to receive(:open).with(%r(.*tmp\/git_ssh\/[a-f0-9-]{36}\/secret_key_file), 'w', 0600)
      @accessor.send(:clone_private_repository, secret_key, url, cloned_path)
    end

    it 'will call File.open method for create git-ssh.sh' do
      expect(File).to receive(:open).with(%r(.*tmp\/git_ssh\/[a-f0-9-]{36}\/git-ssh.sh), 'w', 0700)
      @accessor.send(:clone_private_repository, secret_key, url, cloned_path)
    end

    it 'will clone with ssh repository to temporary directory' do
      env = { 'GIT_SSH' => %r(.*tmp\/git_ssh\/[a-f0-9-]{36}\/git-ssh.s) }
      expect(Open3).to receive(:capture3).with(env, 'git', 'clone', "#{url}", %r(.*tmp\/patterns\/[a-f0-9-]{36}))
      @accessor.send(:clone_private_repository, secret_key, url, cloned_path)
    end

    it 'will remove created git_ssh files after call clone_private_repository method' do
      expect(FileUtils).to receive(:rm_r).with(%r{/tmp/git_ssh/[a-f0-9-]{36}}, force: true)
      @accessor.send(:clone_private_repository, secret_key, url, cloned_path)
    end

    it 'will remove created git_ssh files when failed to clone repository' do
      status = double('status', success?: false)
      allow(Open3).to receive(:capture3).and_return(['', '', status])
      expect(FileUtils).to receive(:rm_r).with(%r{/tmp/git_ssh/[a-f0-9-]{36}}, force: true)
      @accessor.send(:clone_private_repository, secret_key, url, cloned_path)
    end
  end

  describe '#checkout_revision' do
    before do
      allow(Dir).to receive(:chdir).and_yield
      status = double('status', success?: true)
      allow(Open3).to receive(:capture3).and_return(['', '', status])
    end

    it 'will change current directory to cloned repoitory and restore current directory after exit' do
      expect(Dir).to receive(:chdir).with(%r{/tmp/patterns/[a-f0-9-]{36}}).and_yield
      @accessor.send(:checkout_revision, cloned_path, revision)
    end

    it 'will change branch to specified revision when revision has specified' do
      expect(Open3).to receive(:capture3).with('git', 'checkout', revision)
      @accessor.send(:checkout_revision, cloned_path, revision)
    end

    it 'won\'t change branch when revision is nil' do
      expect(Open3).not_to receive(:capture3).with('git', 'checkout', nil)
      @accessor.send(:checkout_revision, cloned_path, revision)
    end
  end

  describe '#clone_repositories' do
    before do
      allow(FileUtils).to receive(:rm_r)
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:rename)
      @pattern_snapshots = []
      @pattern_snapshots << FactoryGirl.create(:pattern_snapshot)
      allow(@accessor).to receive(:clone_repository).and_return(archives_directory)
      allow(@pattern_snapshots[0]).to receive(:freeze_pattern)
    end

    it 'will remove cloned repository after yield block' do
      expect(FileUtils).to receive(:rm_r).with(%r{/tmp/archives/[a-f0-9-]{36}}, force: true)
      @accessor.send(:clone_repositories, @pattern_snapshots, archives_directory) {}
    end

    it 'will raise error when block does not given' do
      expect { @accessor.send(:clone_repositories, @pattern_snapshots, archives_directory) }.to raise_error('PatternAccessor#cloen_repositories needs block')
    end
  end
end
