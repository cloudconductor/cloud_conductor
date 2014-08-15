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
module CloudConductor
  describe DNSClient do
    describe '#update' do
      before do
        @dummy_config = { dns_keyfile: '/etc/testkey', dns_server: 'test_dnsserver', dns_ttl: 100 }
        CloudConductor::Config.stub_chain(:cloudconductor, :configuration).and_return(@dummy_config)
      end

      it 'update record' do
        dns_client = DNSClient.new
        Open3.stub(:capture3).and_return('out1', 'err1', 'nsupdate1')
        Open3.should_receive(:capture3).with(
          'sudo /usr/bin/nsupdate -k /etc/testkey',
          stdin_data: "server test_dnsserver\n" \
                      "update delete test_domain\n" \
                      "send\n" \
                      "update add test_domain 100 A 10.0.0.1\n" \
                      "send\n"
        )
        dns_client.update 'test_domain', '10.0.0.1'
      end
    end
  end
end
