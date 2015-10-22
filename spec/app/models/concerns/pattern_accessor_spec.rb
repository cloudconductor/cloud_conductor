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

    it 'will raise error when block does not given' do
      expect { @accessor.clone_repository(url, revision) }.to raise_error('PatternAccessor#clone_repository needs block')
    end

    it 'will clone repository to temporary directory' do
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
      expect { @accessor.clone_repository(url, revision) { fail } }.to raise_error
    end
  end

  describe '#load_template' do
    it 'will load template.json that is in cloned repository' do
      template = double('File', read: '{ "key": "value" }')
      allow(File).to receive(:open).with("#{cloned_path}/template.json").and_return(template)

      result = @accessor.send(:load_template, cloned_path)
      expect(result).to eq('key' => 'value')
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
      parameters = @accessor.send(:read_parameters, cloned_path)
      expect(parameters).to be_is_a Hash
      expect(parameters.keys).to eq %w(KeyName SSHLocation WebInstanceType WebImageId)
      expect(parameters['KeyName']['MinLength']).to eq '1'
    end
  end

  describe '#read_roles' do
    it 'raise error when Resources does not exist' do
      allow(@accessor).to receive(:load_template).and_return({})
      expect { @accessor.send(:read_roles, cloned_path) }.to raise_error('Resources was not found')
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
end
