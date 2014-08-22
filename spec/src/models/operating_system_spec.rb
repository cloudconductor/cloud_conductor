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
describe OperatingSystem do
  describe '.candidates' do
    it 'return empty when OperatingSystem table is empty' do
      result = OperatingSystem.candidates([{ name: 'centos', version: '= 6.5' }])
      expect(result).to be_empty
    end

    describe 'with data' do
      before do
        OperatingSystem.destroy_all
        @centos64 = FactoryGirl.create(:operating_system, name: 'centos', version: '6.4')
        @centos65 = FactoryGirl.create(:operating_system, name: 'centos', version: '6.5')
        @ubuntu1403 = FactoryGirl.create(:operating_system, name: 'ubuntu', version: '14.03')
        @ubuntu1404 = FactoryGirl.create(:operating_system, name: 'ubuntu', version: '14.04')
      end

      it 'return empty when arguments is nil' do
        result = OperatingSystem.candidates(nil)
        expect(result).to be_empty
      end

      it 'return empty when arguments is empty' do
        result = OperatingSystem.candidates([])
        expect(result).to be_empty
      end

      it 'raise error when version format is invalid' do
        expect { OperatingSystem.candidates([{ name: 'centos', version: '> 6.5' }]) }.to raise_error
      end

      it 'return candidate os when specified single os' do
        result = OperatingSystem.candidates([{ name: 'centos', version: '= 6.5' }])
        expect(result).to match_array([@centos65])
      end

      it 'return candidates os when specified multiple os' do
        result = OperatingSystem.candidates([{ name: 'centos', version: '= 6.5' }, { name: 'ubuntu', version: '= 14.03' }])
        expect(result).to match_array([@centos65, @ubuntu1403])
      end

      it 'ignore part of argument that contains unsupported os' do
        result = OperatingSystem.candidates([{ name: 'centos', version: '= 6.5' }, { name: 'windows', version: '= 8.1' }])
        expect(result).to match_array([@centos65])
      end
    end
  end
end
