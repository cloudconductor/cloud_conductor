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
  include_context 'default_resources'

  let(:today) { Date.today.strftime('%Y%m%d') }

  before do
    @history = ApplicationHistory.new
    @history.application = application
    @history.domain = 'example.com'
    @history.type = 'static'
    @history.protocol = 'http'
    @history.url = 'http://example.com/'
    @history.revision = 'master'
    @history.pre_deploy = 'echo pre'
    @history.post_deploy = 'echo post'
    @history.parameters = '{ "dummy": "value" }'

    # @event = double(:event, fire: 1)
    # allow(@event).to receive_message_chain(:find, :finished?).and_return(true)
    # allow(@event).to receive_message_chain(:find, :success?).and_return(true)
    # allow_any_instance_of(System).to receive(:event).and_return(@event)
  end

  describe '#save' do
    it 'create with valid parameters' do
      expect { @history.save! }.to change { ApplicationHistory.count }.by(1)
    end

    it 'call #allocate_version callback' do
      expect(@history).to receive(:allocate_version)
      @history.save!
    end
  end

  describe '#allocate_version' do
    it 'assign version on first history automatically when version does not specified' do
      @history.send(:allocate_version)
      expect(@history.version).to eq(today + '-001')
    end

    it 'assign version on second or later history automatically when version does not specified' do
      application.histories << FactoryGirl.build(:application_history, application: application)
      application.histories << FactoryGirl.build(:application_history, application: application)

      @history.send(:allocate_version)
      expect(@history.version).to eq(today + '-003')
    end

    it 'assign version that is based on the current date when version does not specified' do
      application.histories << FactoryGirl.build(:application_history, application: application, version: '20001122-005')

      @history.send(:allocate_version)
      expect(@history.version).to eq(today + '-001')
    end
  end

  describe '#valid?' do
    it 'returns true when valid model' do
      expect(@history.valid?).to be_truthy
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

  describe '#payload' do
    it 'return payload that contains application information' do
      expected_payload = satisfy do |payload|
        expect(payload[:cloudconductor]).to be_a Hash
        expect(payload[:cloudconductor][:applications]).to be_a Hash
        expect(payload[:cloudconductor][:applications].keys).to eq([application.name])

        application_payload = payload[:cloudconductor][:applications][application.name]
        expect(application_payload).to be_a Hash

        expect(application_payload.keys).to eq(%i(domain type version protocol url revision pre_deploy post_deploy parameters))
        expect(application_payload[:domain]).to eq(@history.domain)
        expect(application_payload[:type]).to eq(@history.type)
        expect(application_payload[:version]).to eq(@history.version)
        expect(application_payload[:protocol]).to eq(@history.protocol)
        expect(application_payload[:url]).to eq(@history.url)
        expect(application_payload[:revision]).to eq(@history.revision)
        expect(application_payload[:pre_deploy]).to eq(@history.pre_deploy)
        expect(application_payload[:post_deploy]).to eq(@history.post_deploy)
        expect(application_payload[:parameters]).to eq(JSON.parse(@history.parameters, symbolize_names: true))
      end

      expect(@history.payload).to expected_payload
    end

    it 'return payload that does not contains revision when it is unset' do
      @history.revision = nil

      application_payload = @history.payload[:cloudconductor][:applications][application.name]
      expect(application_payload.keys).not_to be_include(:revision)
    end

    it 'return payload that does not contains pre_deploy when it is unset' do
      @history.pre_deploy = nil

      application_payload = @history.payload[:cloudconductor][:applications][application.name]
      expect(application_payload.keys).not_to be_include(:pre_deploy)
    end

    it 'return payload that does not contains post_deploy when it is unset' do
      @history.post_deploy = nil

      application_payload = @history.payload[:cloudconductor][:applications][application.name]
      expect(application_payload.keys).not_to be_include(:post_deploy)
    end
  end
end
