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
describe PatternHistory do
  include_context 'default_resources'

  let(:cloned_path) { File.expand_path("./tmp/patterns/#{SecureRandom.uuid}") }

  it 'include PatternAccessor' do
    expect(PatternHistory).to be_include(PatternAccessor)
  end

  before do
    @history = PatternHistory.new
    @history.blueprint_history = FactoryGirl.build(:blueprint_history, patterns: [@history])
    @history.pattern = pattern

    allow(@history).to receive(:freeze_pattern)
    allow(@history).to receive(:create_images)
  end

  describe '#initialize' do
    it 'set os_version to default' do
      expect(@history.os_version).to eq('default')
    end
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @history.save! }.to change { PatternHistory.count }.by(1)
    end
  end

  describe '#destroy' do
    before do
      allow(@history).to receive(:check_pattern_usage).and_return(true)
      allow_any_instance_of(Image).to receive(:destroy_image).and_return(true)
    end

    it 'will call #check_pattern_usage' do
      expect(@history).to receive(:check_pattern_usage)
      @history.destroy
    end

    it 'delete all image records' do
      @history.images << FactoryGirl.create(:image, pattern_history: @history)

      expect(@history.images.size).to eq(1)
      expect { @history.destroy }.to change { Image.count }.by(-1)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@history.valid?).to be_truthy
    end

    it 'returns false when blueprint_history is unset' do
      @history.blueprint_history = nil
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when pattern is unset' do
      @history.pattern = nil
      expect(@history.valid?).to be_falsey
    end
  end

  describe '#as_json' do
    it 'contains status' do
      allow(@history).to receive(:status).and_return(:CREATE_COMPLETE)
      hash = @history.as_json
      expect(hash['status']).to eq(:CREATE_COMPLETE)
    end

    it 'doesn\'t contain parameters' do
      hash = @history.as_json
      expect(hash['parameters']).to be_nil
    end
  end

  describe '#status' do
    before do
      @history.images << FactoryGirl.create(:image, pattern_history: @history, status: :PROGRESS)
      @history.images << FactoryGirl.create(:image, pattern_history: @history, status: :PROGRESS)
      @history.images << FactoryGirl.create(:image, pattern_history: @history, status: :PROGRESS)
    end

    it 'return status that integrated status over all images' do
      expect(@history.status).to eq(:PROGRESS)
    end

    it 'return :PROGRESS when least one image has progress status' do
      @history.images[0].status = :CREATE_COMPLETE

      expect(@history.status).to eq(:PROGRESS)
    end

    it 'return :ERROR when pattern hasn\'t images' do
      @history.images.delete_all
      expect(@history.status).to eq(:ERROR)
    end

    it 'return :CREATE_COMPLETE when all images have CREATE_COMPLETE status' do
      @history.images[0].status = :CREATE_COMPLETE
      @history.images[1].status = :CREATE_COMPLETE
      @history.images[2].status = :CREATE_COMPLETE

      expect(@history.status).to eq(:CREATE_COMPLETE)
    end

    it 'return error when least one image has error status' do
      @history.images[0].status = :CREATE_COMPLETE
      @history.images[1].status = :PROGRESS
      @history.images[2].status = :ERROR

      expect(@history.status).to eq(:ERROR)
    end
  end

  describe '#freeze_pattern' do
    before do
      allow(@history).to receive(:freeze_pattern).and_call_original
      allow(@history).to receive(:clone_repository).and_yield(cloned_path)
      allow(@history).to receive(:load_metadata).and_return({})
      allow(@history).to receive(:read_parameters).and_return({})
      allow(@history).to receive(:read_roles).and_return([])
      allow(@history).to receive(:freeze_revision)
    end

    it 'will call #clone_repository' do
      expect(@history).to receive(:clone_repository)
      @history.send(:freeze_pattern)
    end

    it 'will call #load_metadata' do
      expect(@history).to receive(:load_metadata)
      @history.send(:freeze_pattern)
    end

    it 'will call #read_parameters' do
      expect(@history).to receive(:read_parameters)
      @history.send(:freeze_pattern)
    end

    it 'will call #read_roles' do
      expect(@history).to receive(:read_roles)
      @history.send(:freeze_pattern)
    end

    it 'will call #freeze_revision' do
      expect(@history).to receive(:freeze_revision)
      @history.send(:freeze_pattern)
    end
  end

  describe '#create_images' do
    before do
      base_image
      @history.name = 'name'
      @history.roles = 'nginx'
      @history.os_version = 'default'
      allow(@history).to receive(:create_images).and_call_original
      allow(@history).to receive(:update_images)
      allow(CloudConductor::PackerClient).to receive_message_chain(:new, :build).and_yield('dummy' => {})
    end

    it 'create image each cloud and role' do
      @history.roles = 'nginx'
      expect { @history.send(:create_images) }.to change { @history.images.size }.by(1)
    end

    it 'will call PackerClient#build with url, revision, name of clouds, role, pattern_name and consul_secret_key' do
      parameters = {
        pattern_name: @history.name,
        patterns: {},
        role: 'nginx',
        consul_secret_key: @history.blueprint_history.consul_secret_key
      }
      parameters[:patterns][@history.name] = {
        url: @history.url,
        revision: @history.revision
      }

      packer_client = CloudConductor::PackerClient.new
      allow(CloudConductor::PackerClient).to receive(:new).and_return(packer_client)
      expect(packer_client).to receive(:build).with(anything, parameters)
      @history.send(:create_images)
    end

    it 'call #update_images with packer results' do
      expect(@history).to receive(:update_images).with('dummy' => {})
      @history.send(:create_images)
    end
  end

  describe '#update_images' do
    it 'update status of all images' do
      results = {
        'aws-default----nginx' => {
          status: :SUCCESS,
          image: 'ami-12345678'
        },
        'openstack-default----nginx' => {
          status: :ERROR,
          message: 'dummy_message'
        }
      }

      base_image_aws = FactoryGirl.create(:base_image, cloud: FactoryGirl.create(:cloud, :aws, name: 'aws'))
      base_image_openstack = FactoryGirl.create(:base_image, cloud: FactoryGirl.create(:cloud, :openstack, name: 'openstack'))
      FactoryGirl.create(:image, pattern_history: @history, base_image: base_image_aws, role: 'nginx')
      FactoryGirl.create(:image, pattern_history: @history, base_image: base_image_openstack, role: 'nginx')
      @history.send(:update_images, results)

      aws = Image.where(name: 'aws-default----nginx').first
      expect(aws.status).to eq(:CREATE_COMPLETE)
      expect(aws.image).to eq('ami-12345678')
      expect(aws.message).to be_nil

      openstack = Image.where(name: 'openstack-default----nginx').first
      expect(openstack.status).to eq(:ERROR)
      expect(openstack.image).to be_nil
      expect(openstack.message).to eq('dummy_message')
    end
  end

  describe '#freeze_revision' do
    it 'execute git log command' do
      allow(Dir).to receive(:chdir).and_yield
      command = 'git log --pretty=format:%H --max-count=1'
      expect(@history).to receive(:`).with(command).and_return('9b274710215f5879549a910beb7199a1bfd40bc9')
      @history.send(:freeze_revision, cloned_path)
      expect(@history.revision).to eq('9b274710215f5879549a910beb7199a1bfd40bc9')
    end
  end

  describe '#check_pattern_usage' do
    it 'raise exception when some stacks use this pattern history' do
      @history.stacks << FactoryGirl.build(:stack)
      expect { @history.send(:check_pattern_usage) }.to raise_error('Some stacks use this pattern')
    end
  end

  describe '#filtered_parameters' do
    before do
      @history.parameters = <<-EOS
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
      parameters = @history.filtered_parameters
      expect(parameters.keys).to eq %w(KeyName SSHLocation WebInstanceType)
    end

    it 'return all parameters when specified option' do
      parameters = @history.filtered_parameters(true)
      expect(parameters.keys).to eq %w(KeyName SSHLocation WebImageId WebInstanceType)
    end
  end
end
