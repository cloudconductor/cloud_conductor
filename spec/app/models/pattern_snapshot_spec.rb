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
describe PatternSnapshot do
  include_context 'default_resources'

  let(:cloned_path) { File.expand_path("./tmp/patterns/#{SecureRandom.uuid}") }
  let(:archived_path) { File.join('/tmp/archives/', "#{SecureRandom.uuid}.tar") }

  it 'include PatternAccessor' do
    expect(PatternSnapshot).to be_include(PatternAccessor)
  end

  before do
    allow_any_instance_of(Project).to receive(:create_preset_roles)

    @pattern = FactoryGirl.build(:pattern_snapshot)
    @pattern.blueprint_history = FactoryGirl.build(:blueprint_history, pattern_snapshots: [@pattern], project: project)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @pattern.save! }.to change { PatternSnapshot.count }.by(1)
    end
  end

  describe '#destroy' do
    before do
      allow(@pattern).to receive(:check_pattern_usage).and_return(true)
      allow_any_instance_of(Image).to receive(:destroy_image).and_return(true)
    end

    it 'will call #check_pattern_usage' do
      expect(@pattern).to receive(:check_pattern_usage)
      @pattern.destroy
    end

    it 'delete all image records' do
      @pattern.images << FactoryGirl.build(:image, pattern_snapshot: @pattern)
      @pattern.save!

      pattern = PatternSnapshot.eager_load(:images).find(@pattern)

      expect(pattern.images.size).to eq(1)
      expect { pattern.destroy }.to change { Image.count }.by(-1)
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@pattern.valid?).to be_truthy
    end

    it 'returns false when blueprint_history is unset' do
      @pattern.blueprint_history = nil
      expect(@pattern.valid?).to be_falsey
    end
  end

  describe '#as_json' do
    it 'contains status' do
      allow(@pattern).to receive(:status).and_return(:CREATE_COMPLETE)
      hash = @pattern.as_json
      expect(hash['status']).to eq(:CREATE_COMPLETE)
    end

    it 'doesn\'t contain parameters' do
      hash = @pattern.as_json
      expect(hash['parameters']).to be_nil
    end
  end

  describe '#status' do
    before do
      @pattern.images << FactoryGirl.build(:image, pattern_snapshot: @pattern, status: :PROGRESS)
      @pattern.images << FactoryGirl.build(:image, pattern_snapshot: @pattern, status: :PROGRESS)
      @pattern.images << FactoryGirl.build(:image, pattern_snapshot: @pattern, status: :PROGRESS)
    end

    it 'return status that integrated status over all images' do
      expect(@pattern.status).to eq(:PROGRESS)
    end

    it 'return :PROGRESS when least one image has progress status' do
      @pattern.images[0].status = :CREATE_COMPLETE

      expect(@pattern.status).to eq(:PROGRESS)
    end

    it 'return :CREATE_COMPLETE when pattern hasn\'t images' do
      @pattern.images.delete_all
      expect(@pattern.status).to eq(:CREATE_COMPLETE)
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

  describe '#freeze_pattern' do
    before do
      metadata = {
        name: 'name',
        type: 'platform',
        providers: { aws: ['cloud_formation'] },
        supports: [
          {
            platform: 'CentOS',
            platform_version: '6.5'
          }
        ],
        roles: %w(web ap)
      }
      allow(@pattern).to receive(:freeze_pattern).and_call_original
      allow(@pattern).to receive(:load_metadata).and_return(metadata)
      allow(@pattern).to receive(:read_parameters).and_return({})
      allow(@pattern).to receive(:freeze_revision)
      allow(@pattern).to receive(:support?).and_return(true)
    end

    it 'will call #load_metadata' do
      expect(@pattern).to receive(:load_metadata)
      @pattern.send(:freeze_pattern, cloned_path)
    end

    it 'will call #read_parameters' do
      expect(@pattern).to receive(:read_parameters)
      @pattern.send(:freeze_pattern, cloned_path)
    end

    it 'will call #freeze_revision' do
      expect(@pattern).to receive(:freeze_revision)
      @pattern.send(:freeze_pattern, cloned_path)
    end

    it 'set attributes from metadata' do
      @pattern.send(:freeze_pattern, cloned_path)
      expect(@pattern.name).to eq('name')
      expect(@pattern.type).to eq('platform')
      expect(@pattern.providers).to eq('{"aws":["cloud_formation"]}')
      expect(@pattern.roles).to eq('["web","ap"]')
    end

    it 'set nil to providers when metadata does not contain providers' do
      allow(@pattern).to receive(:load_metadata).and_return({})

      @pattern.send(:freeze_pattern, cloned_path)
      expect(@pattern.providers).to be_nil
    end

    it 'raise error when #support? return false' do
      allow(@pattern).to receive(:support?).and_return(false)
      expect { @pattern.send(:freeze_pattern, cloned_path) }.to raise_error(RuntimeError)
    end
  end

  describe '#create_images' do
    before do
      base_image
      @pattern.name = 'name'
      @pattern.roles = '["nginx"]'
      @pattern.platform = 'centos'
      allow(@pattern).to receive(:create_images).and_call_original
      allow(@pattern).to receive(:update_images)
      allow(CloudConductor::PackerClient).to receive_message_chain(:new, :build) { |_, _, block| block.call }
    end

    it 'create image each cloud and role' do
      expect { @pattern.send(:create_images, archived_path, &proc {}) }.to change { @pattern.images.size }.by(1)
    end

    it 'will call PackerClient#build with url, revision, name of clouds, role, pattern_name, consul_secret_key, ssh_public_key and archived_path' do
      parameters = {
        pattern_name: @pattern.name,
        role: 'nginx',
        consul_secret_key: @pattern.blueprint_history.consul_secret_key,
        ssh_public_key: @pattern.blueprint_history.ssh_public_key,
        archived_path: archived_path
      }

      packer_client = CloudConductor::PackerClient.new
      allow(CloudConductor::PackerClient).to receive(:new).and_return(packer_client)
      block = proc {}
      expect(packer_client).to receive(:build).with(anything, parameters, block)
      @pattern.send(:create_images, archived_path, &block)
    end
  end

  describe '#update_images' do
    it 'update status of all images' do
      results = {
        'aws-centos-6.5----nginx' => {
          status: :SUCCESS,
          image: 'ami-12345678'
        },
        'openstack-centos-6.5----nginx' => {
          status: :ERROR,
          message: 'dummy_message'
        }
      }

      cloud_aws = FactoryGirl.build(:cloud, :aws, name: 'aws', project: project)
      cloud_openstack = FactoryGirl.build(:cloud, :openstack, name: 'openstack', project: project)
      base_image_aws = FactoryGirl.create(:base_image, cloud: cloud_aws, platform: 'centos', platform_version: '6.5')
      base_image_openstack = FactoryGirl.create(:base_image, cloud: cloud_openstack, platform: 'centos', platform_version: '6.5')
      FactoryGirl.create(:image, pattern_snapshot: @pattern, base_image: base_image_aws, cloud: cloud_aws, role: 'nginx')
      FactoryGirl.create(:image, pattern_snapshot: @pattern, base_image: base_image_openstack, cloud: cloud_openstack, role: 'nginx')
      @pattern.send(:update_images, results)

      aws = Image.where(name: 'aws-centos-6.5----nginx').first
      expect(aws.status).to eq(:CREATE_COMPLETE)
      expect(aws.image).to eq('ami-12345678')
      expect(aws.message).to be_nil

      openstack = Image.where(name: 'openstack-centos-6.5----nginx').first
      expect(openstack.status).to eq(:ERROR)
      expect(openstack.image).to be_nil
      expect(openstack.message).to eq('dummy_message')
    end
  end

  describe '#freeze_revision' do
    it 'execute git log command' do
      allow(Dir).to receive(:chdir).and_yield
      command = 'git log --pretty=format:%H --max-count=1'
      expect(@pattern).to receive(:`).with(command).and_return('9b274710215f5879549a910beb7199a1bfd40bc9')
      @pattern.send(:freeze_revision, cloned_path)
      expect(@pattern.revision).to eq('9b274710215f5879549a910beb7199a1bfd40bc9')
    end
  end

  describe '#check_pattern_usage' do
    it 'raise exception when some stacks use this pattern history' do
      @pattern.stacks << FactoryGirl.build(:stack)
      expect { @pattern.send(:check_pattern_usage) }.to raise_error('Some stacks use this pattern')
    end
  end

  describe '#filtered_parameters' do
    before do
      @pattern.parameters = <<-EOS
        {
          "cloud_formation": {
            "WebImageId" : {
              "Description" : "[computed] DBServer Image Id. This parameter is automatically filled by CloudConductor.",
              "Type" : "String"
            },
            "WebInstanceType" : {
              "Description" : "WebServer instance type",
              "Type" : "String"
            }
          },
          "terraform": {
            "aws": {
              "web_image_id" : {
                "description" : "[computed] WebServer Image Id. This parameter is automatically filled by CloudConductor."
              },
              "web_instance_type" : {
                "description" : "WebServer instance type",
                "default" : "t2.small"
              }
            },
            "openstack": {
              "ap_image_id" : {
                "description" : "[computed] APServer Image Id. This parameter is automatically filled by CloudConductor."
              },
              "ap_instance_type" : {
                "description" : "APServer instance type",
                "default" : "t2.small"
              }
            }
          }
        }
      EOS
    end

    it 'return parameters without [computed] annotation' do
      expect(@pattern.filtered_parameters).to eq(
        'cloud_formation' => {
          'WebInstanceType' => {
            'Description' => 'WebServer instance type',
            'Type' => 'String'
          }
        },
        'terraform' => {
          'aws' => {
            'web_instance_type' => {
              'description' => 'WebServer instance type',
              'default' => 't2.small'
            }
          },
          'openstack' => {
            'ap_instance_type' => {
              'description' => 'APServer instance type',
              'default' => 't2.small'
            }
          }
        }
      )
    end

    it 'return all parameters when specified option' do
      expect(@pattern.filtered_parameters(true)).to eq(
        'cloud_formation' => {
          'WebImageId' => {
            'Description' => '[computed] DBServer Image Id. This parameter is automatically filled by CloudConductor.',
            'Type' => 'String'
          },
          'WebInstanceType' => {
            'Description' => 'WebServer instance type',
            'Type' => 'String'
          }
        },
        'terraform' => {
          'aws' => {
            'web_image_id' => {
              'description' => '[computed] WebServer Image Id. This parameter is automatically filled by CloudConductor.'
            },
            'web_instance_type' => {
              'description' => 'WebServer instance type',
              'default' => 't2.small'
            }
          },
          'openstack' => {
            'ap_image_id' => {
              'description' => '[computed] APServer Image Id. This parameter is automatically filled by CloudConductor.'
            },
            'ap_instance_type' => {
              'description' => 'APServer instance type',
              'default' => 't2.small'
            }
          }
        }
      )
    end

    it 'reject openstack parameters when specified aws cloud' do
      expect(@pattern.filtered_parameters(true, ['aws'])).to eq(
        'cloud_formation' => {
          'WebImageId' => {
            'Description' => '[computed] DBServer Image Id. This parameter is automatically filled by CloudConductor.',
            'Type' => 'String'
          },
          'WebInstanceType' => {
            'Description' => 'WebServer instance type',
            'Type' => 'String'
          }
        },
        'terraform' => {
          'aws' => {
            'web_image_id' => {
              'description' => '[computed] WebServer Image Id. This parameter is automatically filled by CloudConductor.'
            },
            'web_instance_type' => {
              'description' => 'WebServer instance type',
              'default' => 't2.small'
            }
          }
        }
      )
    end

    it 'reject unused openstack parameters when specified cloud' do
      expect(@pattern.filtered_parameters(true, nil, ['cloud_formation'])).to eq(
        'cloud_formation' => {
          'WebImageId' => {
            'Description' => '[computed] DBServer Image Id. This parameter is automatically filled by CloudConductor.',
            'Type' => 'String'
          },
          'WebInstanceType' => {
            'Description' => 'WebServer instance type',
            'Type' => 'String'
          }
        }
      )
    end
  end

  describe '#support?' do
    before do
      @supports = [
        {
          platform: 'centos',
          platform_version: '6.5'
        },
        {
          platform: 'centos',
          platform_version: '7.1'
        }
      ]
    end

    it 'return true when target platform match metadata' do
      expect(@pattern.send(:support?, @supports, 'centos')).to be_truthy
    end

    it 'return true when target platform family match metadata' do
      expect(@pattern.send(:support?, @supports, 'redhat')).to be_truthy
    end

    it 'return true when target platform and platform_version match metadata exactly' do
      expect(@pattern.send(:support?, @supports, 'ubuntu')).to be_falsey
    end
  end
end
