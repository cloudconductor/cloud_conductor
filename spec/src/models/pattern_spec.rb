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
    YAML.stub(:load_file).and_return({})
    @pattern.stub(:`).and_return('')
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
      expect(@pattern.status).to eq(:pending)
    end

    it 'return pending when least one image has pending status' do
      @pattern.images[0].status = :created

      expect(@pattern.status).to eq(:pending)
    end

    it 'return created when all images have created status' do
      @pattern.images[0].status = :created
      @pattern.images[1].status = :created
      @pattern.images[2].status = :created

      expect(@pattern.status).to eq(:created)
    end

    it 'return error when least one image has error status' do
      @pattern.images[0].status = :created
      @pattern.images[1].status = :pending
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
    it 'will clone repository to temporary directory' do
      command = %r(git clone #{@pattern.uri} tmp/[a-f0-9-]{36})
      @pattern.should_receive(:system).with(command).and_return(true)
      @pattern.save!
    end

    it 'will load metadata.yml in cloned repository' do
      path = %r(tmp/[a-f0-9-]{36}/metadata.yml)
      YAML.should_receive(:load_file).with(path).and_return({})
      @pattern.save!
    end

    it 'will change branch to specified revision when revision has specified' do
      command = /git checkout dummy/
      @pattern.should_receive(:system).with(command).and_return(true)

      @pattern.revision = 'dummy'
      @pattern.save!
    end

    it 'won\'t change branch when revision is nil' do
      command = /git checkout/
      @pattern.should_not_receive(:system).with(command)

      @pattern.save!
    end

    it 'update name attribute with name in metadata' do
      metadata = { name: 'name' }
      YAML.should_receive(:load_file).and_return(metadata)

      @pattern.save!

      expect(@pattern.name).to eq('name')
    end

    it 'update description attribute with description in metadata' do
      metadata = { description: 'description' }
      YAML.should_receive(:load_file).and_return(metadata)

      @pattern.save!

      expect(@pattern.description).to eq('description')
    end

    it 'update type attribute with type in metadata' do
      metadata = { type: 'Platform' }
      YAML.should_receive(:load_file).and_return(metadata)

      @pattern.save!

      expect(@pattern.type).to eq('Platform')
    end

    it 'update revision attribute when revision is nil' do
      hash = SecureRandom.hex(20)
      command = /git log --pretty=format:%H --max-count=1 $/
      @pattern.should_receive(:`).with(command).and_return(hash)

      @pattern.save!

      expect(@pattern.revision).to eq(hash)
    end

    it 'update revision attribute when revision is branch/tag' do
      hash = SecureRandom.hex(20)
      command = /git log --pretty=format:%H --max-count=1 dummy$/
      @pattern.should_receive(:`).with(command).and_return(hash)

      @pattern.revision = 'dummy'
      @pattern.save!

      expect(@pattern.revision).to eq(hash)
    end

    it 'update revision attribute when revision is hash' do
      hash = SecureRandom.hex(20)
      command = /git log --pretty=format:%H --max-count=1 #{hash}$/
      @pattern.should_receive(:`).with(command).and_return(hash)

      @pattern.revision = hash
      @pattern.save!

      expect(@pattern.revision).to eq(hash)
    end
  end
end
