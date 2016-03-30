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
describe CloudConductor::Config do
  describe '.from_file' do
    it 'load config from specified ruby file' do
      allow(IO).to receive(:read).and_return('')
      CloudConductor::Config.from_file 'dummy.rb'
    end

    it 'update config with new values what are specified in ruby file' do
      expect(CloudConductor::Config.application_log_path).to eq('log/conductor_test.log')

      allow(IO).to receive(:read).and_return('application_log_path "log/conductor_development.log"')
      CloudConductor::Config.from_file 'dummy.rb'

      expect(CloudConductor::Config.application_log_path).to eq('log/conductor_development.log')
    end
  end

  it 'returns default values' do
    configurables = CloudConductor::Config.configurables
    event_configurables = CloudConductor::Config.event.configurables
    system_build_configurables = CloudConductor::Config.system_build.configurables
    audit_log_configurables = CloudConductor::Config.audit_log.configurables
    expect(configurables[:application_log_path].default).to eq('log/conductor_production.log')
    expect(configurables[:access_log_path].default).to eq('log/conductor_access.log')
    expect(event_configurables[:timeout].default).to eq(1800)
    expect(system_build_configurables[:timeout].default).to eq(1800)
    expect(audit_log_configurables[:export_limit].default).to eq(100)
  end
end
