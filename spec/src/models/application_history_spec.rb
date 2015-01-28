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

    @event = double(:event, fire: 1)
    allow(@event).to receive_message_chain(:find, :finished?).and_return(true)
    allow(@event).to receive_message_chain(:find, :success?).and_return(true)
    allow_any_instance_of(System).to receive(:event).and_return(@event)
    @today = Date.today.strftime('%Y%m%d')
  end

  describe '#initialize' do
    it 'set status to :not_yet' do
      expect(@history.status).to eq(:not_yet)
    end
  end

  describe '#status' do
    it 'returns application history status as symbol' do
      @history.status = 'sample'
      expect(@event).not_to receive(:find)
      expect(@history.status).to eq(:sample)
    end

    it 'request status to consul when status is progress' do
      @history.status = :progress
      @history.event = 'dummy_event_id'
      expect(@event).to receive(:find).with('dummy_event_id')
      @history.status
    end

    it 'return :progress if event has\'nt finished' do
      @history.status = :progress
      @history.event = 'dummy_event_id'
      allow(@event).to receive_message_chain(:find, :finished?).and_return(false)

      expect(@history.status).to eq(:progress)
    end

    it 'return :success and save status if event has finished with success status' do
      @history.status = :progress
      @history.event = 'dummy_event_id'
      allow(@event).to receive_message_chain(:find, :success?).and_return(true)

      @history.save!

      expect(@history.status).to eq(:deployed)
      expect(ApplicationHistory.find(@history.id).status).to eq(:deployed)
    end

    it 'return :error and save status if event has finished without success status' do
      @history.status = :progress
      @history.event = 'dummy_event_id'
      allow(@event).to receive_message_chain(:find, :success?).and_return(false)

      @history.save!

      expect(@history.status).to eq(:error)
      expect(ApplicationHistory.find(@history.id).status).to eq(:error)
    end
  end

  describe '#save' do
    it 'create with valid parameters' do
      count = ApplicationHistory.count

      @history.save!

      expect(ApplicationHistory.count).to eq(count + 1)
    end

    it 'assign version on first history automatically when version does not specified' do
      @history.save!

      expect(@history.version).to eq(@today + '-001')
    end

    it 'assign version on second or later history automatically when version does not specified' do
      @application.histories << FactoryGirl.build(:application_history, application: @application)
      @application.histories << FactoryGirl.build(:application_history, application: @application)

      @history.save!

      expect(@history.version).to eq(@today + '-003')
    end

    it 'assign version that is based on the current date when version does not specified' do
      @application.histories << FactoryGirl.build(:application_history, application: @application, version: '20001122-5')

      @history.save!

      expect(@history.version).to eq(@today + '-001')
    end

    describe 'before_save' do
      it 'will call consul_request if system already created' do
        expect(@history).to receive(:consul_request)
        @history.save!
      end

      it 'will not call consul_request if system hasn\'t created' do
        @history.application.system.ip_address = nil

        expect(@history).not_to receive(:consul_request)
        @history.save!
      end

      it 'will not call consul_request if already deployed' do
        @history.status = :deployed

        expect(@history).not_to receive(:consul_request)
        @history.save!
      end
    end

    describe '#consul_request' do
      it 'change status when call consul_request' do
        expect(@history.attributes['status']).to eq('not_yet')
        expect(@history.event).to be_nil

        @history.save!

        expect(@history.attributes['status']).to eq('progress')
        expect(@history.event).not_to be_nil
      end

      it 'contains domain, type, version, protocol, url and parameters in payload when request to consul' do
        @history.application.name = 'dummy'

        payload = {
          cloudconductor: {
            applications: {
              'dummy' => {
                domain: 'example.com',
                type: 'static',
                version: "#{@today}-001",
                protocol: 'http',
                url: 'http://example.com/',
                parameters: { dummy: 'value' }
              }
            }
          }
        }

        expect(@event).to receive(:fire).with(:deploy, payload)
        @history.save!
      end

      it 'contains revision, pre_deploy and post_deploy in payload if these value has been set' do
        @history.revision = 'master'
        @history.pre_deploy = 'yum install dummy'
        @history.post_deploy = 'service dummy restart'

        expected_payload = satisfy do |payload|
          target = payload[:cloudconductor][:applications][@history.application.name]
          expect(target).to include(
            revision: 'master',
            pre_deploy: 'yum install dummy',
            post_deploy: 'service dummy restart'
          )
        end

        expect(@event).to receive(:fire).with(:deploy, expected_payload)
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

  describe '#dup' do
    it 'copy attributes without status' do
      @history.status = :deployed
      result = @history.dup
      expect(result.status).to eq(:not_yet)
    end
  end
end
