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
  before do
    @cloud_aws = FactoryGirl.create(:cloud_aws)
    @cloud_openstack = FactoryGirl.create(:cloud_openstack)

    @pattern = Pattern.new
    @pattern.url = 'http://example.com/pattern.git'
    @pattern.clouds << @cloud_aws
    @pattern.clouds << @cloud_openstack

    allow(@pattern).to receive(:system).and_return(true)
    allow(Dir).to receive(:chdir).and_yield
    allow(YAML).to receive(:load_file).and_return({})
    allow(File).to receive(:open).and_call_original
    double = double('File', read: '{ "Parameters": {}, "Resources": {} }')
    allow(File).to receive(:open).with(/template.json/).and_return double
  end

  describe '#initialize' do
    it 'set protocol to git' do
      expect(@pattern.protocol).to eq('git')
    end
  end

  it 'create with valid parameters' do
    count = Pattern.count

    @pattern.save!

    expect(Pattern.count).to eq(count + 1)
  end

  it 'delete all relatioship between pattern and cloud' do
    expect(@pattern.clouds).not_to be_empty

    @pattern.clouds.delete_all

    expect(@pattern.clouds).to be_empty
    expect(@pattern.patterns_clouds).to be_empty
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@pattern.valid?).to be_truthy
    end

    it 'returns false when url is unset' do
      @pattern.url = nil
      expect(@pattern.valid?).to be_falsey
    end

    it 'returns false when url is invalid URL' do
      @pattern.url = 'invalid url'
      expect(@pattern.valid?).to be_falsey
    end

    it 'returns false when clouds is empty' do
      @pattern.clouds.delete_all
      expect(@pattern.valid?).to be_falsey
    end

    it 'returns false when clouds collection has duplicate cloud' do
      @pattern.clouds.delete_all
      @pattern.clouds << @cloud_aws
      @pattern.clouds << @cloud_aws
      expect(@pattern.valid?).to be_falsey
    end
  end

  describe '#status' do
    before do
      @pattern.images << FactoryGirl.create(:image)
      @pattern.images << FactoryGirl.create(:image)
      @pattern.images << FactoryGirl.create(:image)
    end

    it 'return status that integrated status over all images' do
      expect(@pattern.status).to eq(:PROGRESS)
    end

    it 'return :PROGRESS when least one image has progress status' do
      @pattern.images[0].status = :CREATE_COMPLETE

      expect(@pattern.status).to eq(:PROGRESS)
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

  describe '#destroy' do
    it 'delete pattern record' do
      count = Pattern.count
      @pattern.save!
      @pattern.destroy
      expect(Pattern.count).to eq(count)
    end

    it 'delete relation record on PatternsCloud' do
      count = PatternsCloud.count
      @pattern.save!
      expect(PatternsCloud.count).to_not eq(count)
      @pattern.destroy
      expect(PatternsCloud.count).to eq(count)
    end
  end

  describe '#before_save' do
    before do
      allow(@pattern).to receive(:systemu).with('consul keygen').and_return([double('status', 'success?' => true), 'dummy key', ''])
      @path = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}")
    end

    it 'will call sub-routine' do
      path_pattern = %r{/tmp/patterns/[a-f0-9-]{36}}
      expect(@pattern).to receive(:clone_repository).and_yield(path_pattern)
      expect(@pattern).to receive(:load_metadata).with(path_pattern).and_return({})
      expect(@pattern).to receive(:load_roles).with(path_pattern).and_return(['dummy'])
      expect(@pattern).to receive(:update_metadata).with(path_pattern, {})
      expect(@pattern).to receive(:create_images).with(anything, 'dummy', nil, 'dummy key')
      @pattern.save!
    end

    it 'raise error when some errors occurred while execute `consul keygen` command' do
      allow(@pattern).to receive(:systemu).with('consul keygen').and_return([double('status', 'success?' => false), '', 'error'])
      expect { @pattern.save! }.to raise_error
    end

    describe '#clone_repository' do
      before do
        allow(FileUtils).to receive(:rm_r)
      end

      it 'will raise error when block does not given' do
        expect { @pattern.send(:clone_repository) }.to raise_error('Pattern#clone_repository needs block')
      end

      it 'will clone repository to temporary directory' do
        command = %r(git clone #{@pattern.url} .*tmp/patterns/[a-f0-9-]{36})
        expect(@pattern).to receive(:system).with(command).and_return(true)
        @pattern.send(:clone_repository) {}
      end

      it 'will change current directory to cloned repoitory and restore current directory after exit' do
        expect(Dir).to receive(:chdir).with(%r{/tmp/patterns/[a-f0-9-]{36}}).and_yield
        @pattern.send(:clone_repository) {}
      end

      it 'will change branch to specified revision when revision has specified' do
        command = /git checkout dummy/
        expect(@pattern).to receive(:system).with(command).and_return(true)

        @pattern.revision = 'dummy'
        @pattern.send(:clone_repository) {}
      end

      it 'won\'t change branch when revision is nil' do
        command = /git checkout/
        expect(@pattern).not_to receive(:system).with(command)

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

    describe '#load_metadata' do
      it 'will load metadata.yml in cloned repository' do
        metadata = { name: 'name' }
        path = %r(tmp/patterns/[a-f0-9-]{36}/metadata.yml)
        expect(YAML).to receive(:load_file).with(path).and_return(metadata)

        result = @pattern.send(:load_metadata, @path)
        expect(result).to eq(metadata.with_indifferent_access)
      end
    end

    describe '#load_roles' do
      it 'raise error when Resources does not exist' do
        template = '{}'
        double = double('File', read: template)
        allow(File).to receive(:open).with(/template.json/).and_return(double)
        expect { @pattern.send(:load_roles, @path) }.to raise_error('Resources was not found')
      end

      it 'will load template.json and get role list' do
        template = <<-EOS
          {
            "Resources": {
              "Dummy1": {
                "Type": "AWS::EC2::Instance",
                "Metadata": {
                  "Role": "nginx"
                }
              },
              "Dummy2": {
                "Type": "AWS::AutoScaling::LaunchConfiguration",
                "Metadata": {
                  "Role": "rails"
                }
              },
              "Dummy3": {
                "Type": "AWS::EC2::Instance",
                "Metadata": {
                  "Role": "rails"
                }
              },
              "Dummy4": {
                "Type": "AWS::EC2::Instance"
              }
            }
          }
        EOS
        double = double('File', read: template)
        allow(File).to receive(:open).with(/template.json/).and_return(double)

        roles = %w(nginx rails Dummy4)
        expect(@pattern.send(:load_roles, @path)).to match_array(roles)
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
              "webInstanceType" : {
                "Description" : "WebServer instance type",
                "Type" : "String",
                "Default" : "t2.small"
              },
              "webImageId" : {
                "Description" : "DBServer Image Id. This parameter is automatically filled by CloudConductor.",
                "Type" : "String"
              }
            }
          }
        EOS
        allow(File).to receive(:open).with(/template.json/).and_return(double('File', read: template))
        parameters = @pattern.send(:load_parameters, @path)
        expect(parameters).to be_instance_of Hash
        expect(parameters.keys).to eq %w(KeyName SSHLocation webInstanceType webImageId)
        expect(parameters['KeyName']['MinLength']).to eq '1'
      end
    end

    describe '#update_metadata' do
      before do
        allow(Dir).to receive(:chdir).and_yield
      end

      it 'update name attribute with name in metadata' do
        metadata = { name: 'name' }
        @pattern.send(:update_metadata, @path, metadata)

        expect(@pattern.name).to eq('name')
      end

      it 'update description attribute with description in metadata' do
        metadata = { description: 'description' }
        @pattern.send(:update_metadata, @path, metadata)

        expect(@pattern.description).to eq('description')
      end

      it 'update type attribute with type in metadata' do
        metadata = { type: 'platform' }
        @pattern.send(:update_metadata, @path, metadata)

        expect(@pattern.type).to eq(:platform)
      end

      it 'update parameters attribute with parameters in template' do
        parameters = { keyname: { Type: 'String' } }
        allow(@pattern).to receive(:load_parameters).with(@path).and_return(parameters)
        @pattern.send(:update_metadata, @path, {})
        expect(@pattern.parameters).to eq(parameters.to_json)
      end

      it 'update revision attribute when revision is nil' do
        hash = SecureRandom.hex(20)
        command = /git log --pretty=format:%H --max-count=1$/
        expect(@pattern).to receive(:`).with(command).and_return(hash)

        @pattern.send(:update_metadata, @path, {})

        expect(@pattern.revision).to eq(hash)
      end

      it 'update revision attribute when revision is branch/tag' do
        hash = SecureRandom.hex(20)
        command = /git log --pretty=format:%H --max-count=1$/
        expect(@pattern).to receive(:`).with(command).and_return(hash)

        @pattern.revision = 'dummy'
        @pattern.send(:update_metadata, @path, {})

        expect(@pattern.revision).to eq(hash)
      end

      it 'update revision attribute when revision is hash' do
        hash = SecureRandom.hex(20)
        command = /git log --pretty=format:%H --max-count=1$/
        expect(@pattern).to receive(:`).with(command).and_return(hash)

        @pattern.revision = hash
        @pattern.send(:update_metadata, @path, {})

        expect(@pattern.revision).to eq(hash)
      end
    end

    describe '#create_images' do
      before do
        allow_any_instance_of(CloudConductor::PackerClient).to receive(:build)
        @operating_systems = [FactoryGirl.create(:centos), FactoryGirl.create(:ubuntu)]
      end

      it 'create image each cloud, operating_system and role' do
        count = Image.count

        @pattern.send(:create_images, @operating_systems, 'nginx', 'dummy_platform', 'dummy key')
        @pattern.save!

        expect(Image.count).to eq(count + @pattern.clouds.size * @operating_systems.size * 1)
      end

      it 'will call PackerClient#build with url, revision, name of clouds, operating_systems, role, pattern_name and consul_secret_key' do
        parameters = {}
        parameters[:repository_url] = @pattern.url
        parameters[:revision] = @pattern.revision
        parameters[:clouds] = @pattern.clouds.map(&:name)
        parameters[:operating_systems] = @operating_systems.map(&:name)
        parameters[:role] = 'nginx'
        parameters[:pattern_name] = 'dummy_platform'
        parameters[:consul_secret_key] = 'dummy key'
        expect_any_instance_of(CloudConductor::PackerClient).to receive(:build).with(parameters)

        @pattern.send(:create_images, @operating_systems, 'nginx', 'dummy_platform', 'dummy key')
      end

      it 'update status of all images when call block' do
        results = {
          "#{@cloud_aws.name}#{BaseImage::SPLITTER}#{@operating_systems.first.name}" => {
            status: :SUCCESS,
            image: 'ami-12345678'
          },
          "#{@cloud_openstack.name}#{BaseImage::SPLITTER}#{@operating_systems.first.name}" => {
            status: :ERROR,
            message: 'dummy_message'
          }
        }
        allow(CloudConductor::PackerClient).to receive_message_chain(:new, :build) do |*_, &block|
          @pattern.save!
          block.call results
        end
        @pattern.send(:create_images, @operating_systems, 'nginx', 'dummy_platform', 'dummy key')

        aws = Image.where(cloud: @cloud_aws, operating_system: @operating_systems.first, role: 'nginx').first
        expect(aws.status).to eq(:CREATE_COMPLETE)
        expect(aws.image).to eq('ami-12345678')
        expect(aws.message).to be_nil

        openstack = Image.where(cloud: @cloud_openstack, operating_system: @operating_systems.first, role: 'nginx').first
        expect(openstack.status).to eq(:ERROR)
        expect(openstack.image).to be_nil
        expect(openstack.message).to eq('dummy_message')
      end
    end

    describe '#parameters' do
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
            "webImageId" : {
              "Description" : "[computed] DBServer Image Id. This parameter is automatically filled by CloudConductor.",
              "Type" : "String"
            },
            "webInstanceType" : {
              "Description" : "WebServer instance type",
              "Type" : "String"
            }
          }
        EOS
      end

      it 'return parameters without [computed] annotation' do
        parameters = JSON.parse(@pattern.parameters)
        expect(parameters.keys).to eq %w(KeyName SSHLocation webInstanceType)
      end

      it 'return all parameters when specified option' do
        parameters = JSON.parse(@pattern.parameters true)
        expect(parameters.keys).to eq %w(KeyName SSHLocation webImageId webInstanceType)
      end
    end
  end
end
