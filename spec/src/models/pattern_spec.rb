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
    @pattern.uri = 'http://example.com/pattern.git'
    @pattern.clouds << @cloud_aws
    @pattern.clouds << @cloud_openstack

    @pattern.stub(:system).and_return(true)
    Dir.stub(:chdir)
    YAML.stub(:load_file).and_return({})
    File.stub(:open).and_call_original
    double = double('File', read: '{ "Resources" : {} }')
    File.stub(:open).with(/template.json/).and_return double
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

    it 'returns false when uri is unset' do
      @pattern.uri = nil
      expect(@pattern.valid?).to be_falsey
    end

    it 'returns false when uri is invalid URL' do
      @pattern.uri = 'invalid url'
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
      expect(@pattern.status).to eq(:processing)
    end

    it 'return processing when least one image has processing status' do
      @pattern.images[0].status = :created

      expect(@pattern.status).to eq(:processing)
    end

    it 'return created when all images have created status' do
      @pattern.images[0].status = :created
      @pattern.images[1].status = :created
      @pattern.images[2].status = :created

      expect(@pattern.status).to eq(:created)
    end

    it 'return error when least one image has error status' do
      @pattern.images[0].status = :created
      @pattern.images[1].status = :processing
      @pattern.images[2].status = :error

      expect(@pattern.status).to eq(:error)
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
      @path = File.expand_path("./tmp/patterns/#{SecureRandom.uuid}")
    end

    it 'will call sub-routine' do
      path_pattern = %r{/tmp/patterns/[a-f0-9-]{36}}
      @pattern.should_receive(:clone_repository).and_yield(path_pattern)
      @pattern.should_receive(:load_metadata).with(path_pattern).and_return({})
      @pattern.should_receive(:load_roles).with(path_pattern).and_return(['dummy'])
      @pattern.should_receive(:update_attributes).with({})
      @pattern.should_receive(:create_images).with(anything, 'dummy')
      @pattern.save!
    end

    describe '#clone_repository' do
      it 'will clone repository to temporary directory' do
        command = %r(git clone #{@pattern.uri} .*tmp/patterns/[a-f0-9-]{36})
        @pattern.should_receive(:system).with(command).and_return(true)
        @pattern.send(:clone_repository) { |_| }
      end

      it 'will change branch to specified revision when revision has specified' do
        command = /git checkout dummy/
        @pattern.should_receive(:system).with(command).and_return(true)

        @pattern.revision = 'dummy'
        @pattern.send(:clone_repository) { |_| }
      end

      it 'won\'t change branch when revision is nil' do
        command = /git checkout/
        @pattern.should_not_receive(:system).with(command)

        @pattern.send(:clone_repository) { |_| }
      end
    end

    describe '#load_metadata' do
      it 'will load metadata.yml in cloned repository' do
        metadata = { name: 'name' }
        path = %r(tmp/patterns/[a-f0-9-]{36}/metadata.yml)
        YAML.should_receive(:load_file).with(path).and_return(metadata)

        result = @pattern.send(:load_metadata, @path)
        expect(result).to eq(metadata.with_indifferent_access)
      end
    end

    describe '#load_roles' do
      it 'raise error when Resources does not exist' do
        template = '{}'
        double = double('File', read: template)
        File.stub(:open).with(/template.json/).and_return(double)
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
        File.stub(:open).with(/template.json/).and_return(double)

        roles = %w(nginx rails Dummy4)
        expect(@pattern.send(:load_roles, @path)).to match_array(roles)
      end
    end

    describe '#update_attributes' do
      it 'update name attribute with name in metadata' do
        metadata = { name: 'name' }
        @pattern.send(:update_attributes, metadata)

        expect(@pattern.name).to eq('name')
      end

      it 'update description attribute with description in metadata' do
        metadata = { description: 'description' }
        @pattern.send(:update_attributes, metadata)

        expect(@pattern.description).to eq('description')
      end

      it 'update type attribute with type in metadata' do
        metadata = { type: 'Platform' }
        @pattern.send(:update_attributes, metadata)

        expect(@pattern.type).to eq('Platform')
      end

      it 'update revision attribute when revision is nil' do
        hash = SecureRandom.hex(20)
        command = /git log --pretty=format:%H --max-count=1$/
        @pattern.should_receive(:`).with(command).and_return(hash)

        @pattern.send(:update_attributes, {})

        expect(@pattern.revision).to eq(hash)
      end

      it 'update revision attribute when revision is branch/tag' do
        hash = SecureRandom.hex(20)
        command = /git log --pretty=format:%H --max-count=1$/
        @pattern.should_receive(:`).with(command).and_return(hash)

        @pattern.revision = 'dummy'
        @pattern.send(:update_attributes, {})

        expect(@pattern.revision).to eq(hash)
      end

      it 'update revision attribute when revision is hash' do
        hash = SecureRandom.hex(20)
        command = /git log --pretty=format:%H --max-count=1$/
        @pattern.should_receive(:`).with(command).and_return(hash)

        @pattern.revision = hash
        @pattern.send(:update_attributes, {})

        expect(@pattern.revision).to eq(hash)
      end
    end

    describe '#create_images' do
      before do
        CloudConductor::PackerClient.any_instance.stub(:build)
        @operating_systems = [FactoryGirl.create(:centos), FactoryGirl.create(:ubuntu)]
      end

      it 'create image each cloud, operating_system and role' do
        count = Image.count

        @pattern.send(:create_images, @operating_systems, 'nginx')
        @pattern.save!

        expect(Image.count).to eq(count + @pattern.clouds.size * @operating_systems.size * 1)
      end

      it 'will call PackerClient#build with uri, revision, name of clouds, operating_systems and role' do
        args = []
        args << @pattern.uri
        args << @pattern.revision
        args << @pattern.clouds.map(&:name)
        args << @operating_systems.map(&:name)
        args << 'nginx'
        CloudConductor::PackerClient.any_instance.should_receive(:build).with(*args)

        @pattern.send(:create_images, @operating_systems, 'nginx')
      end

      it 'update status of all images when call block' do
        results = {
          "#{@cloud_aws.name}-#{@operating_systems.first.name}" => {
            status: :success,
            image: 'ami-12345678'
          },
          "#{@cloud_openstack.name}-#{@operating_systems.first.name}" => {
            status: :error,
            message: 'dummy_message'
          }
        }
        CloudConductor::PackerClient.stub_chain(:new, :build) do |*_, &block|
          @pattern.save!
          block.call results
        end
        @pattern.send(:create_images, @operating_systems, 'nginx')

        aws = Image.where(cloud: @cloud_aws, operating_system: @operating_systems.first, role: 'nginx').first
        expect(aws.status).to eq(:created)
        expect(aws.image).to eq('ami-12345678')
        expect(aws.message).to be_nil

        openstack = Image.where(cloud: @cloud_openstack, operating_system: @operating_systems.first, role: 'nginx').first
        expect(openstack.status).to eq(:error)
        expect(openstack.image).to be_nil
        expect(openstack.message).to eq('dummy_message')
      end
    end
  end
end
