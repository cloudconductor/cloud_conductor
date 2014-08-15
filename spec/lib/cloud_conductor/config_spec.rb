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
      IO.stub(:read).and_return('')
      CloudConductor::Config.from_file 'dummy.rb'
    end

    it 'update config with new values what are specified in ruby file' do
      IO.stub(:read).and_return('log_file "/tmp/dummy"')
      CloudConductor::Config.from_file 'dummy.rb'

      expect(CloudConductor::Config.log_file).to eq('/tmp/dummy')
    end
  end

  it 'returns default values' do
    configurables = CloudConductor::Config.configurables
    expect(configurables[:log_file].default.inspect).to eq(STDOUT.inspect)
    expect(configurables[:log_level].default).to eq(:info)
  end
end
