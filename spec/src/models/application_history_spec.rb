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
describe ApplicationHistory do
  before do
    @application = FactoryGirl.create(:application)

    @history = ApplicationHistory.new
    @history.application = @application
    @history.domain = 'example.com'
    @history.type = 'static'
    @history.protocol = 'http'
    @history.url = 'http://example.com/'
    @history.parameters = '{ "dummy": "value" }'

    @serf_client = double('serf_client', call: nil)
    @application.system.stub(:serf).and_return(@serf_client)
  end

  describe '#save' do
    it 'create with valid parameters' do
      count = ApplicationHistory.count

      @history.save!

      expect(ApplicationHistory.count).to eq(count + 1)
    end

    it 'assign version on first history automatically when version does not specified' do
      @history.version = nil
      @history.save!

      expect(@history.version).to eq(1)
    end

    it 'assign version on second or later history automatically when version does not specified' do
      FactoryGirl.create(:application_history, application: @application)
      FactoryGirl.create(:application_history, application: @application)

      @history.version = nil
      @history.save!

      expect(@history.version).to eq(3)
    end

    describe 'before_save' do
      before do
        @serf_client = double('serf_client')
        @history.application.system.stub(:serf).and_return(@serf_client)
      end

      it 'will call serf request with payload if revison does not specified' do
        @serf_client.should_receive(:call).with('event', 'deploy', hash_including(:url, :parameters))
        @history.save!
      end

      it 'will call serf request with payload if revison specified' do
        @history.revision = 'develop'
        @serf_client.should_receive(:call).with('event', 'deploy', hash_including(:url, :revision, :parameters))
        @history.save!
      end
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@history.valid?).to be_truthy
    end

    it 'returns false when domain is unset' do
      @history.domain = nil
      expect(@history.valid?).to be_falsey

      @history.domain = ''
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when type is unset' do
      @history.type = nil
      expect(@history.valid?).to be_falsey

      @history.type = ''
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when protocol is unset' do
      @history.protocol = nil
      expect(@history.valid?).to be_falsey

      @history.protocol = ''
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when protocol is invalid' do
      @history.protocol = 'dummy'
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when application is unset' do
      @history.application = nil
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when url is unset' do
      @history.url = nil
      expect(@history.valid?).to be_falsey

      @history.url = ''
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when url is invalid URL' do
      @history.url = 'dummy'
      expect(@history.valid?).to be_falsey
    end

    it 'returns false when parameters is invalid JSON' do
      @history.parameters = 'dummy'
      expect(@history.valid?).to be_falsey
    end
  end
end
